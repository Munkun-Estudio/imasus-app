require "test_helper"

class MaterialsControllerTest < ActionDispatch::IntegrationTest
  MATERIALS_BATCH_SIZE = 12

  setup do
    Tag.seed_from_yaml!
    Material.seed_from_yaml!
    @password = "correcthorsebatterystaple"
    @admin = User.create!(name: "Admin", email: "materials-admin@example.com", password: @password, role: :admin)
    @facilitator = User.create!(name: "Facilitator", email: "materials-facilitator@example.com", password: @password, role: :facilitator)
    @participant = User.create!(name: "Participant", email: "materials-participant@example.com", password: @password, role: :participant)
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: @password }
  end

  # Matches the per-card marker rendered in the view so we can assert
  # presence, counts, and ordering without being coupled to CSS classes.
  def card_selector(material = nil)
    material ? %([data-material="#{material.slug}"]) : "[data-material]"
  end

  # --- Basic rendering ------------------------------------------------------

  test "GET /materials returns 200" do
    get materials_url
    assert_response :success
  end

  test "GET /materials renders only the first batch of seeded materials" do
    get materials_url
    first_batch = Material.order(:position).limit(MATERIALS_BATCH_SIZE)
    later_batch = Material.order(:position).offset(MATERIALS_BATCH_SIZE)

    first_batch.each do |material|
      assert_select card_selector(material)
    end
    later_batch.each do |material|
      assert_select card_selector(material), count: 0
    end
    assert_select "turbo-frame[data-role='materials-next-page'][src*='page=2']"
  end

  test "GET /materials renders materials ordered by position" do
    get materials_url
    slugs_in_render = css_select(card_selector).map { |node| node["data-material"] }
    expected = Material.order(:position).limit(MATERIALS_BATCH_SIZE).pluck(:slug)
    assert_equal expected, slugs_in_render
  end

  test "GET /materials renders the trade name for each first-batch material" do
    get materials_url
    Material.order(:position).limit(MATERIALS_BATCH_SIZE).each do |material|
      assert_includes response.body, material.trade_name
    end
  end

  test "GET /materials?page=2 returns the next Turbo-frame batch" do
    get materials_url(page: 2), headers: { "Turbo-Frame" => "materials_page_2" }

    assert_response :success
    assert_select "turbo-frame#materials_page_2"
    Material.order(:position).offset(MATERIALS_BATCH_SIZE).limit(MATERIALS_BATCH_SIZE).each do |material|
      assert_select card_selector(material)
    end
    Material.order(:position).limit(MATERIALS_BATCH_SIZE).each do |material|
      assert_select card_selector(material), count: 0
    end
  end

  # --- Chip-filter rail ------------------------------------------------------

  test "GET /materials renders chips for seeded tags that have matches, grouped by facet" do
    get materials_url
    Tag::FACETS.each do |facet|
      Tag.where(facet: facet).find_each do |tag|
        expected_count = tag.materials.count
        assert_select %([data-facet="#{facet}"] a[href*="#{facet}=#{tag.slug}"]),
                      expected_count.positive? ? { minimum: 1 } : { count: 0 },
                      "expected chip visibility for facet=#{facet} slug=#{tag.slug} count=#{expected_count}"
      end
    end
  end

  # --- Filtering: within-facet OR --------------------------------------------

  test "GET /materials?origin_type=plants narrows to materials tagged with plants" do
    get materials_url(origin_type: "plants")
    tag = Tag.find_by!(facet: "origin_type", slug: "plants")
    tagged = tag.materials.reorder(:position).limit(MATERIALS_BATCH_SIZE).pluck(:slug).uniq
    untagged = Material.where.not(id: tag.materials.select(:id)).pluck(:slug)

    tagged.each { |slug| assert_select %([data-material="#{slug}"]) }
    untagged.each { |slug| assert_select %([data-material="#{slug}"]), count: 0 }
  end

  test "GET /materials?origin_type=plants,seaweed unions slugs (OR within facet)" do
    get materials_url(origin_type: "plants,seaweed")
    plants  = Tag.find_by!(facet: "origin_type", slug: "plants")
    seaweed = Tag.find_by!(facet: "origin_type", slug: "seaweed")
    union = (plants.materials.pluck(:id) | seaweed.materials.pluck(:id))
    rendered_slugs = css_select(card_selector).map { |node| node["data-material"] }
    assert rendered_slugs.any?, "expected the first filtered batch to render cards"
    assert_empty rendered_slugs - Material.where(id: union).pluck(:slug)
    Material.where.not(id: union).pluck(:slug).each do |slug|
      assert_select %([data-material="#{slug}"]), count: 0
    end
  end

  # --- Filtering: across-facet AND -------------------------------------------

  test "GET /materials with two facets applies AND across them" do
    plants   = Tag.find_by!(facet: "origin_type", slug: "plants")
    clothing = Tag.find_by!(facet: "application", slug: "clothing")
    expected_ids = plants.materials.pluck(:id) & clothing.materials.pluck(:id)

    get materials_url(origin_type: "plants", application: "clothing")

    expected_slugs = Material.where(id: expected_ids).order(:position).limit(MATERIALS_BATCH_SIZE).pluck(:slug)
    expected_slugs.each { |slug| assert_select %([data-material="#{slug}"]) }
    Material.where.not(id: expected_ids).pluck(:slug).each do |slug|
      assert_select %([data-material="#{slug}"]), count: 0
    end
  end

  # --- Robustness: unknown chips --------------------------------------------

  test "GET /materials with an unknown chip slug is ignored, no error" do
    get materials_url(origin_type: "spaceship")
    assert_response :success
    Material.order(:position).limit(MATERIALS_BATCH_SIZE).each do |material|
      assert_select card_selector(material)
    end
  end

  test "GET /materials with an unknown facet name is ignored, no error" do
    get materials_url(nonsense_facet: "anything")
    assert_response :success
    Material.order(:position).limit(MATERIALS_BATCH_SIZE).each do |material|
      assert_select card_selector(material)
    end
  end

  # --- Search ---------------------------------------------------------------

  test "GET /materials?q=cypress narrows by trade_name" do
    get materials_url(q: "cypress")
    cypress = Material.find_by(slug: "lifematerials-cypress-denim")
    assert_not_nil cypress, "expected the Cypress Denim seed entry to exist"
    assert_select card_selector(cypress)
    # sanity: something that doesn't contain "cypress" in its trade name or
    # English description should not be in the filtered result
    unrelated = Material.where.not("LOWER(trade_name) LIKE ?", "%cypress%")
                         .where.not("description_translations->>'en' ILIKE ?", "%cypress%")
                         .first
    assert_not_nil unrelated
    assert_select %([data-material="#{unrelated.slug}"]), count: 0
  end

  test "GET /materials?q=... searches the current-locale description JSONB key" do
    needle = "quoquolorem"
    material = Material.create!(
      trade_name:               "Locale search probe",
      availability_status:      "commercial",
      description_translations: { "en" => "An English description.", "es" => "Contiene #{needle} aquí." }
    )

    I18n.with_locale(:es) do
      get materials_url(q: needle, locale: "es")
      assert_select %([data-material="#{material.slug}"])
    end

    I18n.with_locale(:en) do
      get materials_url(q: needle, locale: "en")
      assert_select %([data-material="#{material.slug}"]), count: 0
    end
  end

  test "GET /materials combines chip filters and search with AND" do
    plants = Tag.find_by!(facet: "origin_type", slug: "plants")
    cypress = Material.find_by(slug: "lifematerials-cypress-denim")
    assert_not_nil cypress
    # Ensure Cypress Denim is actually tagged as plants (seed invariant)
    assert_includes cypress.tags_for(:origin_type).pluck(:slug), "plants"

    get materials_url(origin_type: "plants", q: "cypress")

    assert_select card_selector(cypress)
    # a non-cypress plants material should be excluded
    other_plants = plants.materials
                         .where.not(id: cypress.id)
                         .where.not("LOWER(trade_name) LIKE ?", "%cypress%")
                         .first
    assert_not_nil other_plants
    assert_select %([data-material="#{other_plants.slug}"]), count: 0
  end

  test "GET /materials?q=nothingwillmatch renders the empty state" do
    get materials_url(q: "zzz-definitely-no-such-material-zzz")
    assert_response :success
    assert_select card_selector, count: 0
    assert_select "[data-role='empty-state']"
  end

  # --- Per-chip counts -------------------------------------------------------

  test "GET /materials renders a match count next to each visible chip" do
    get materials_url
    Tag::FACETS.each do |facet|
      Tag.where(facet: facet).find_each do |tag|
        expected = tag.materials.count
        next if expected.zero?

        assert_select %([data-facet="#{facet}"] [data-chip-slug="#{tag.slug}"] [data-role="chip-count"]),
                      text: expected.to_s,
                      message: "expected count=#{expected} for facet=#{facet} slug=#{tag.slug}"
      end
    end
  end

  # --- Clear-all control -----------------------------------------------------

  test "GET /materials with any filter shows a Clear all control" do
    get materials_url(origin_type: "plants")
    assert_select "a[data-role='clear-all'][href=?]", materials_path
  end

  test "GET /materials without filters does not show the Clear all control" do
    get materials_url
    assert_select "a[data-role='clear-all']", count: 0
  end

  # --- Card-media Stimulus wiring -------------------------------------------

  test "each rendered card has the card-media Stimulus controller wired" do
    get materials_url
    assert_select "[data-controller~='card-media']", count: MATERIALS_BATCH_SIZE
  end

  # --- Cards expose an eye-icon affordance for the preview sidebar ---------

  test "each card renders an open-preview affordance targeting the preview frame" do
    get materials_url
    Material.order(:position).limit(MATERIALS_BATCH_SIZE).each do |material|
      assert_select %([data-material="#{material.slug}"] [data-role="open-preview"][href=?][data-turbo-frame="preview"]),
                    preview_material_path(material.slug)
    end
  end

  # --- Cards link to the detail page (covering link via the title) ----------

  test "each card's trade name links to the material detail page" do
    get materials_url
    Material.order(:position).limit(MATERIALS_BATCH_SIZE).each do |material|
      assert_select %([data-material="#{material.slug}"] a[href=?]),
                    material_path(material.slug),
                    minimum: 1,
                    message: "expected the card for #{material.slug} to contain a link to #{material_path(material.slug)}"
    end
  end

  # --- Preview (Turbo Frame) ------------------------------------------------

  test "GET /materials/:slug/preview returns 200" do
    material = Material.order(:position).first
    get preview_material_url(material.slug)
    assert_response :success
  end

  test "GET /materials/:slug/preview renders trade name, description, and full-page link" do
    material = Material.order(:position).first
    get preview_material_url(material.slug)
    assert_includes response.body, material.trade_name
    assert_includes response.body, material.description_in(:en).to_s.strip[0, 40]
    assert_select "a[href=?]", material_path(material.slug)
  end

  test "GET /materials/:slug/preview renders without the application layout" do
    material = Material.order(:position).first
    get preview_material_url(material.slug)
    assert_no_match(/<html/i, response.body,
                    "preview should render bare, without the application layout")
  end

  test "GET /materials/:slug/preview uses a dialog role and is not modal" do
    material = Material.order(:position).first
    get preview_material_url(material.slug)
    assert_select "[role='dialog'][aria-modal='false']"
  end

  test "GET /materials/:slug/preview returns 404 for unknown slug" do
    get preview_material_url("nope-nothing-here")
    assert_response :not_found
  end

  # --- Show (detail page) ---------------------------------------------------

  test "GET /materials/:slug returns 200 for an existing material" do
    material = Material.order(:position).first
    get material_url(material.slug)
    assert_response :success
    assert_includes response.body, material.trade_name
  end

  test "GET /materials/:slug renders the trade name as an H1" do
    material = Material.order(:position).first
    get material_url(material.slug)
    assert_select "h1", text: material.trade_name
  end

  test "participant does not see material edit affordance" do
    sign_in(@participant)
    material = Material.order(:position).first
    get material_url(material.slug)
    assert_select "[data-role='edit-material']", count: 0
  end

  test "facilitator sees material edit affordance" do
    sign_in(@facilitator)
    material = Material.order(:position).first
    get material_url(material.slug)
    assert_select "[data-role='edit-material'][href=?]", edit_material_path(material)
  end

  test "participant cannot edit a material" do
    sign_in(@participant)
    material = Material.order(:position).first
    get edit_material_url(material.slug)
    assert_redirected_to root_path
  end

  test "facilitator can edit a material" do
    sign_in(@facilitator)
    material = Material.order(:position).first
    get edit_material_url(material.slug)
    assert_response :success
  end

  test "facilitator can update material copy" do
    sign_in(@facilitator)
    material = Material.order(:position).first

    patch material_url(material.slug), params: {
      material: {
        trade_name: material.trade_name,
        availability_status: material.availability_status,
        description_translations: material.description_translations.merge("en" => "Updated curator description.")
      }
    }

    assert_redirected_to material_path(material)
    assert_equal "Updated curator description.", material.reload.description_in(:en)
  end

  test "participant cannot update a material" do
    sign_in(@participant)
    material = Material.order(:position).first

    patch material_url(material.slug), params: {
      material: {
        trade_name: "Hacked"
      }
    }

    assert_redirected_to root_path
    assert_not_equal "Hacked", material.reload.trade_name
  end

  test "GET /materials/:slug returns 404 for unknown slug" do
    get material_url("nope-nothing-here")
    assert_response :not_found
  end

  test "GET /materials/:slug renders a back link to the materials index" do
    material = Material.order(:position).first
    get material_url(material.slug)
    assert_select %(a[href="#{materials_path}"])
  end

  test "GET /materials/:slug renders the description section when present" do
    material = Material.order(:position).first
    get material_url(material.slug)
    assert_select %([data-role="section-description"])
    assert_select %([data-role="section-description"]) do
      assert_select "*", text: /#{Regexp.escape(material.description_in("en")[0, 20])}/
    end
  end

  test "GET /materials/:slug hides sections whose locale-fallback value is blank" do
    translated_attrs = %i[description sensorial_qualities what_problem_it_solves
                          interesting_properties structure]
    material = Material.order(:position).first
    get material_url(material.slug)

    translated_attrs.each do |attr|
      value = material.public_send(:"#{attr}_in", "en")
      selector = %([data-role="section-#{attr}"])
      if value.to_s.strip.present?
        assert_select selector, minimum: 1
      else
        assert_select selector, count: 0
      end
    end
  end

  test "GET /materials/:slug reads translatable content from the current locale when present" do
    material = Material.order(:position).first
    material.update!(description_translations: material.description_translations.merge(
      "es" => "Esta es la descripción en español con palabra única zzztesto."
    ))

    get material_url(material.slug, locale: :es)

    assert_response :success
    assert_includes response.body, "zzztesto"
  end

  test "GET /materials/:slug falls back to the base locale when the target locale is missing" do
    material = Material.order(:position).first
    material.update!(description_translations: material.description_translations.except("es"))

    get material_url(material.slug, locale: :es)

    assert_response :success
    en_snippet = material.description_in("en")[0, 30]
    assert_includes response.body, en_snippet
  end

  test "GET /materials/:slug does not leak translation missing markers" do
    material = Material.order(:position).first
    get material_url(material.slug)
    refute_match(/translation missing/i, response.body)
  end

  test "GET /materials/:slug includes a <meta name=\"description\"> tag with a non-blank value" do
    material = Material.order(:position).first
    get material_url(material.slug)
    assert_select %(meta[name="description"]) do |elements|
      refute_empty elements, "expected <meta name=description> to be present"
      content = elements.first["content"].to_s
      refute content.strip.empty?, "expected meta description to have non-blank content"
    end
  end

  test "GET /materials/:slug sets <title> from the trade name" do
    material = Material.order(:position).first
    get material_url(material.slug)
    assert_select "title", text: /#{Regexp.escape(material.trade_name)}/
  end

  test "GET /materials/:slug renders tag chips grouped by facet" do
    material = Material.joins(:tags).order(:position).first
    get material_url(material.slug)

    Tag::FACETS.each do |facet|
      tags = material.tags_for(facet)
      next if tags.empty?
      assert_select %([data-role="detail-facet"][data-facet="#{facet}"]),
                    minimum: 1
    end
  end

  test "GET /materials/:slug wraps glossary terms within the description prose" do
    material = Material.order(:position).first
    first_word = material.description_in("en").split(/\s+/).find { |w| w.match?(/\A[A-Za-z]{4,}\z/) }
    assert first_word, "seed fixture should have at least one plain-ASCII word in the description"

    GlossaryTerm.create!(
      slug:     "zzz-unique-glossary-slug",
      category: "methodology",
      term_translations:       { "en" => first_word },
      definition_translations: { "en" => "A test term definition." }
    )

    get material_url(material.slug)
    assert_select %([data-role="section-description"] [data-controller~="glossary-popover"]),
                  minimum: 1
    assert_match(/data-glossary-popover-slug-value="zzz-unique-glossary-slug"/, response.body)
  end

  test "GET /materials/:slug drops embedded data URI markdown references from prose" do
    material = Material.create!(
      trade_name: "Embedded Data Material",
      slug: "embedded-data-material",
      availability_status: :commercial,
      description_translations: { "en" => "Plain description." },
      what_problem_it_solves_translations: {
        "en" => "This text should render.\n\n[image1]: <data:image/png;base64,#{'A' * 2000}>"
      }
    )

    get material_url(material.slug)

    assert_response :success
    assert_includes response.body, "This text should render."
    refute_includes response.body, "data:image/png"
  end

  test "GET /materials/:slug hides the media gallery when no assets are attached" do
    material = Material.order(:position).first
    # Seed loader does not attach assets, so this material has none.
    assert_nil material.macro_asset
    assert_empty material.microscopies
    assert_nil material.video_asset

    get material_url(material.slug)
    assert_select %([data-role="material-gallery"]), 0
  end

  test "GET /materials/:slug renders the gallery when a macro asset is attached" do
    material = attach_macro_to(Material.order(:position).first)

    get material_url(material.slug)

    assert_select %([data-role="material-gallery"])
    assert_select %([data-role="gallery-viewer"])
    # With a single media item, thumbnails are not rendered.
    assert_select %([data-role="gallery-thumb"]), 0
  end

  test "GET /materials/:slug renders a thumbnail stack when 2+ media items are attached" do
    material = Material.order(:position).first
    attach_macro_to(material)
    attach_video_to(material)

    get material_url(material.slug)

    assert_select %([data-role="gallery-thumb"]), minimum: 2
    assert_select %([data-role="gallery-thumb"][data-kind="macro"])
    assert_select %([data-role="gallery-thumb"][data-kind="video"])
  end

  test "GET /materials/:slug defaults the active thumbnail to the video when present" do
    material = Material.order(:position).first
    attach_macro_to(material)
    attach_video_to(material)

    get material_url(material.slug)

    assert_select %([data-role="gallery-thumb"][data-kind="video"][data-gallery-active="true"])
    assert_select %([data-role="gallery-thumb"][data-kind="macro"][data-gallery-active="false"])
  end

  test "GET /materials/:slug defaults the active thumbnail to the macro when there is no video" do
    material = Material.order(:position).first
    attach_macro_to(material)
    attach_microscopy_to(material)

    get material_url(material.slug)

    assert_select %([data-role="gallery-thumb"][data-kind="macro"][data-gallery-active="true"])
  end

  test "GET /materials/:slug does not render hidden full-size gallery images" do
    material = Material.order(:position).first
    attach_macro_to(material)
    attach_microscopy_to(material)
    attach_microscopy_to(material, position: 1)

    get material_url(material.slug)

    assert_select %([data-role="gallery-viewer"] img[data-role="gallery-media"]), count: 1
    assert_select %([data-role="gallery-viewer"] img.hidden), count: 0
  end

  test "GET /materials/:slug renders video poster-first without exposing the video blob URL" do
    material = Material.order(:position).first
    attach_macro_to(material)
    attach_video_to(material)

    get material_url(material.slug)

    assert_select %([data-role="deferred-video"][data-media-url=?]),
                  media_material_path(material.slug, key: "video")
    assert_select "video", count: 0
    assert_select "source", count: 0
    refute_includes response.body, "video.mp4"
  end

  test "GET /materials/:slug/media renders the requested full media item" do
    material = Material.order(:position).first
    attach_macro_to(material)

    get media_material_url(material.slug, key: "macro")

    assert_response :success
    assert_select %([data-role="gallery-media"][data-media-key="macro"])
  end

  test "GET /materials/:slug/media renders a video player only after media is requested" do
    material = Material.order(:position).first
    attach_video_to(material)

    get media_material_url(material.slug, key: "video")

    assert_response :success
    assert_select "video[preload='none'] source"
    assert_includes response.body, "video.mp4"
  end

  test "GET /materials/:slug renders the meta sidebar with labelled supplier/availability/origin rows" do
    material = Material.find_by(slug: "pyratex-musa-1") || Material.order(:position).first
    get material_url(material.slug)

    assert_select %([data-role="meta-availability"])
    if material.supplier_name.present? || material.supplier_url.present?
      assert_select %([data-role="meta-supplier"])
    end
    if material.material_of_origin.present?
      assert_select %([data-role="meta-origin"])
    end
  end

  test "GET /materials/:slug groups tag chips under their facet heading" do
    material = Material.joins(:tags).order(:position).first
    get material_url(material.slug)

    Tag::FACETS.each do |facet|
      tags = material.tags_for(facet)
      next if tags.empty?
      assert_select %([data-role="detail-facet-group"][data-facet="#{facet}"]) do
        assert_select "dt", text: I18n.t("materials.index.facets.#{facet}.title")
        assert_select %([data-role="detail-facet"][data-facet="#{facet}"])
      end
    end
  end

  private

  # Attaches a small image fixture to a new MaterialAsset owned by `material`,
  # saving only after the attachment is in place so the presence validator
  # passes.
  def build_asset_with_file(material, kind:, position: 0, filename:, content_type:)
    asset = material.assets.build(kind: kind, position: position)
    asset.file.attach(
      io: file_fixture("sample-image.png").open,
      filename: filename,
      content_type: content_type,
      identify: false
    )
    asset.save!
    material.reload
  end

  def attach_macro_to(material)
    build_asset_with_file(material, kind: :macro, filename: "macro.png", content_type: "image/png")
  end

  def attach_microscopy_to(material, position: 0)
    build_asset_with_file(material, kind: :microscopy, position: position,
                                   filename: "micro-#{position}.png", content_type: "image/png")
  end

  def attach_video_to(material)
    build_asset_with_file(material, kind: :video, filename: "video.mp4", content_type: "video/mp4")
  end
end
