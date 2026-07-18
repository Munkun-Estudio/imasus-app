require "set"

# Compares generic Library storage with the retained Materials compatibility
# columns and attachment aliases. Run before retiring any legacy storage.
class LibraryMigrationVerifier
  Result = Data.define(:counts, :errors) do
    def success?
      errors.empty?
    end
  end

  LEGACY_FIELDS = {
    "supplier_name" => :supplier_name,
    "supplier_url" => :supplier_url,
    "material_of_origin" => :material_of_origin,
    "availability_status" => :availability_status,
    "interesting_properties" => :interesting_properties_translations,
    "structure" => :structure_translations,
    "sensorial_qualities" => :sensorial_qualities_translations,
    "what_problem_it_solves" => :what_problem_it_solves_translations
  }.freeze

  LEGACY_ENUM_FIELDS = %w[availability_status].freeze

  def call
    errors = []
    verify_items(errors)
    verify_terms(errors)
    verify_relationships(errors)
    verify_attachments(errors)
    verify_bookmarks(errors)
    Result.new(counts:, errors: errors.freeze)
  end

  def verify!
    result = call
    return result if result.success?

    raise "Library migration verification failed:\n- #{result.errors.join("\n- ")}"
  end

  private

  def counts
    {
      items: LibraryItem.count,
      published_items: LibraryItem.published.count,
      terms: LibraryTaxonomyTerm.count,
      taggings: LibraryItemTagging.count,
      assets: LibraryItemAsset.count,
      asset_attachments: generic_asset_attachments.count,
      bookmarks: Bookmark.where(bookmarkable_type: "LibraryItem").count
    }.freeze
  end

  def verify_items(errors)
    LibraryItem.of_type("material").find_each do |item|
      compare(errors, item, "title.en", item.trade_name, item.title_in(:en))
      compare(errors, item, "summary", item.description_translations, item.summary_translations)
      LEGACY_FIELDS.each do |field, column|
        legacy = item.public_send(column)
        legacy = Material::AVAILABILITY_STATUSES[legacy] if LEGACY_ENUM_FIELDS.include?(field) && legacy.is_a?(Integer)
        compare(errors, item, field, legacy, item.custom_fields[field])
      end
    end

    missing = LibraryCatalog.current.items.map(&:id) - LibraryItem.pluck(:slug)
    errors << "manifest items missing from storage: #{missing.join(', ')}" if missing.any?
  end

  def verify_terms(errors)
    LibraryTaxonomyTerm.find_each do |term|
      next if term.facet.nil? && !Tag::FACETS.include?(term.taxonomy_key)

      legacy_facet = term.facet.is_a?(Integer) ? Tag::FACETS[term.facet] : term.facet
      compare(errors, term, "taxonomy", legacy_facet, term.taxonomy_key)
    end
  end

  def verify_relationships(errors)
    orphaned_items = LibraryItemTagging.where.not(library_item_id: LibraryItem.select(:id)).count
    orphaned_terms = LibraryItemTagging.where.not(
      library_taxonomy_term_id: LibraryTaxonomyTerm.select(:id)
    ).count
    errors << "#{orphaned_items} taggings reference missing items" if orphaned_items.positive?
    errors << "#{orphaned_terms} taggings reference missing terms" if orphaned_terms.positive?
  end

  def verify_attachments(errors)
    legacy = attachment_tuples("MaterialAsset")
    generic = attachment_tuples("LibraryItemAsset")
    missing = legacy - generic
    extra = generic - legacy
    errors << "#{missing.size} legacy asset attachments are missing generically" if missing.any?
    errors << "#{extra.size} generic asset attachments have no legacy alias" if extra.any?
  end

  def verify_bookmarks(errors)
    Bookmark.where(bookmarkable_type: "LibraryItem").find_each do |bookmark|
      next if LibraryItem.exists?(slug: bookmark.resource_key)

      errors << "bookmark #{bookmark.id} references missing Library item #{bookmark.resource_key.inspect}"
    end
    numeric = Bookmark.where(bookmarkable_type: "Material").where("resource_key ~ '^[0-9]+$'").count
    errors << "#{numeric} numeric Material bookmarks remain" if numeric.positive?
  end

  def compare(errors, record, field, legacy, generic)
    return if normalized(legacy) == normalized(generic)

    errors << "#{record.class.name} #{record.id} differs for #{field}"
  end

  def normalized(value)
    return nil if value.blank?

    value.respond_to?(:as_json) ? value.as_json : value
  end

  def attachment_tuples(record_type)
    ActiveStorage::Attachment.where(record_type:).pluck(:name, :record_id, :blob_id).to_set
  end

  def generic_asset_attachments
    ActiveStorage::Attachment.where(record_type: "LibraryItemAsset")
  end
end
