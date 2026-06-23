require "json"

# Read-only export of the public IMASUS archive into a portable JSON contract.
class StaticArchiveExporter
  SCHEMA_VERSION = 1

  def initialize(output_dir:, now: Time.current, asset_url: nil)
    @output_dir = Pathname(output_dir)
    @now = now
    @asset_url = asset_url || ->(blob) { blob.url }
    @assets = {}
  end

  def export!
    raise ArgumentError, "Output directory must be empty: #{@output_dir}" if @output_dir.exist? && @output_dir.children.any?

    @output_dir.mkpath
    sections = {
      "workshops" => workshops,
      "projects" => projects,
      "materials" => materials,
      "challenges" => challenges,
      "glossary" => glossary_terms
    }
    sections.each { |name, records| write("#{name}.json", records) }
    write("assets.json", @assets.values.sort_by { |asset| asset.fetch("id") })
    write("manifest.json", manifest(sections))
  end

  private

  def workshops
    Workshop.ready_for_listing.order(:starts_on, :slug).map do |workshop|
      {
        "id" => workshop.id, "slug" => workshop.slug, "location" => workshop.location,
        "starts_on" => workshop.starts_on, "ends_on" => workshop.ends_on,
        "title_translations" => workshop.title_translations,
        "description_translations" => workshop.description_translations,
        "agendas" => %w[en es it el].to_h { |locale| [locale, rich_text_payload(workshop.public_send("agenda_#{locale}"), "Workshop", workshop.id, "agenda_#{locale}")] }
      }
    end
  end

  def projects
    Project.active.published.includes(:workshop, :challenge, :members, hero_image_attachment: :blob).order(:slug).map do |project|
      {
        "id" => project.id, "slug" => project.slug, "title" => project.title,
        "language" => project.language, "publication_updated_at" => project.publication_updated_at,
        "workshop_slug" => project.workshop.slug, "challenge_code" => project.challenge&.code,
        "hero_asset_id" => register_attachment(project.hero_image, "Project", project.id, "hero_image"),
        "process_summary" => rich_text_payload(project.process_summary, "Project", project.id, "process_summary"),
        "members" => project.members.order(:name).map { |member| public_member(member) }
      }
    end
  end

  def materials
    Material.includes(:tags, assets: [file_attachment: :blob, poster_attachment: :blob]).order(:position, :slug).map do |material|
      {
        "id" => material.id, "slug" => material.slug, "trade_name" => material.trade_name,
        "supplier_name" => material.supplier_name, "supplier_url" => material.supplier_url,
        "material_of_origin" => material.material_of_origin, "availability_status" => material.availability_status,
        "position" => material.position, "tags" => material.tags.order(:facet, :slug).map { |tag| { "slug" => tag.slug, "facet" => tag.facet } },
        "translations" => Material::TRANSLATED_ATTRIBUTES.to_h { |attribute| [attribute.to_s, material.public_send("#{attribute}_translations")] },
        "assets" => material.assets.sort_by { |asset| [asset.kind, asset.position] }.map { |asset| material_asset(asset) }
      }
    end
  end

  def challenges
    Challenge.by_code.map { |challenge| { "id" => challenge.id, "code" => challenge.code, "category" => challenge.category, "question_translations" => challenge.question_translations, "description_translations" => challenge.description_translations } }
  end

  def glossary_terms
    GlossaryTerm.order(:slug).map { |term| { "id" => term.id, "slug" => term.slug, "category" => term.category, "term_translations" => term.term_translations, "definition_translations" => term.definition_translations, "examples_translations" => term.examples_translations } }
  end

  def material_asset(asset)
    { "id" => asset.id, "kind" => asset.kind, "position" => asset.position,
      "file_asset_id" => register_attachment(asset.file, "MaterialAsset", asset.id, "file"),
      "poster_asset_id" => register_attachment(asset.poster, "MaterialAsset", asset.id, "poster") }
  end

  def public_member(member)
    { "name" => member.name, "institution" => member.institution, "country" => member.country,
      "bio" => member.bio, "profile_links" => participant_profile_links(member) }
  end

  def participant_profile_links(member)
    %i[website_url linkedin_url instagram_url].filter_map { |attribute| member.public_send(attribute) if member.respond_to?(attribute) && member.public_send(attribute).present? }
  end

  def rich_text_payload(rich_text, record_type, record_id, name)
    return nil if rich_text.blank?

    attachments = rich_text.body.attachments
    attachment_ids = attachments.filter_map do |attachment|
      attachable = attachment.attachable
      register_blob(attachable, record_type, record_id, name) if attachable.is_a?(ActiveStorage::Blob)
    end
    html = rewrite_rich_text_attachments(rich_text.body.to_rendered_html_with_layout, attachments, attachment_ids)
    { "html" => html, "asset_ids" => attachment_ids }
  end

  def rewrite_rich_text_attachments(html, attachments, asset_ids)
    return html if attachments.empty?

    fragment = Nokogiri::HTML::DocumentFragment.parse(html)
    figures = fragment.css("figure.attachment")
    raise "Could not map Action Text attachments to rendered figures" unless figures.size == attachments.size

    figures.zip(asset_ids).each do |figure, asset_id|
      raise "Action Text attachment is not an Active Storage blob" if asset_id.blank?

      asset = @assets.fetch(asset_id)
      figure["data-static-asset-id"] = asset_id
      figure.css("[src]").each { |node| node["src"] = asset.fetch("url") }
      figure.css("a[href]").each { |node| node["href"] = asset.fetch("url") }
    end

    rewritten = fragment.to_html
    raise "Action Text export contains a Rails Active Storage URL" if rewritten.include?("/rails/active_storage/")

    rewritten
  end

  def register_attachment(attachment, record_type, record_id, name)
    return unless attachment.attached?

    register_blob(attachment.blob, record_type, record_id, name)
  end

  def register_blob(blob, record_type, record_id, name)
    id = "blob-#{blob.id}"
    url = @asset_url.call(blob)
    raise "Asset export contains a Rails Active Storage URL for blob #{blob.id}" if url.include?("/rails/active_storage/")

    asset = (@assets[id] ||= {
      "id" => id, "blob_id" => blob.id, "key" => blob.key, "url" => url,
      "filename" => blob.filename.to_s, "content_type" => blob.content_type,
      "byte_size" => blob.byte_size, "checksum" => blob.checksum, "used_by" => []
    })
    usage = { "record_type" => record_type, "record_id" => record_id, "attachment_name" => name }
    asset.fetch("used_by") << usage unless asset.fetch("used_by").include?(usage)
    id
  end

  def manifest(sections)
    { "schema_version" => SCHEMA_VERSION, "exported_at" => @now.iso8601,
      "counts" => sections.transform_values(&:size).merge("assets" => @assets.size),
      "files" => sections.keys.index_with { |name| "#{name}.json" }.merge("assets" => "assets.json") }
  end

  def write(filename, payload)
    @output_dir.join(filename).write(JSON.pretty_generate(payload))
  end
end
