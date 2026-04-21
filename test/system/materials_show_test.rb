require "application_system_test_case"

class MaterialsShowTest < ApplicationSystemTestCase
  setup do
    Tag.seed_from_yaml!
    Material.seed_from_yaml!
  end

  test "visiting a material detail page renders header, prose, and back link" do
    material = Material.order(:position).first
    visit material_url(material.slug)

    assert_selector "h1", text: material.trade_name
    assert_selector %([data-role="section-description"])
    assert_selector %(a[href="#{materials_path}"])
  end

  test "back link on the detail page returns to the materials index" do
    material = Material.order(:position).first
    visit material_url(material.slug)
    first(%(a[href="#{materials_path}"])).click
    assert_current_path materials_path
    assert_selector %([data-material])
  end

  test "detail page shows supplier link when supplier_url is present" do
    material = Material.where.not(supplier_url: [ nil, "" ]).order(:position).first
    skip "no seeded material with supplier_url" unless material

    visit material_url(material.slug)
    assert_selector %(a[href="#{material.supplier_url}"])
  end

  test "clicking a gallery thumbnail swaps the active media in the main viewer" do
    material = Material.order(:position).first
    attach_asset(material, kind: :macro,      filename: "macro.png",  content_type: "image/png")
    attach_asset(material, kind: :microscopy, filename: "micro-0.png", content_type: "image/png", position: 0)

    visit material_url(material.slug)

    # Macro starts as the default active thumbnail.
    assert_selector %([data-role="gallery-thumb"][data-kind="macro"][data-gallery-active="true"])
    assert_selector %([data-role="gallery-thumb"][data-kind="microscopy"][data-gallery-active="false"])

    find(%([data-role="gallery-thumb"][data-kind="microscopy"])).click

    assert_selector %([data-role="gallery-thumb"][data-kind="microscopy"][data-gallery-active="true"])
    assert_selector %([data-role="gallery-thumb"][data-kind="macro"][data-gallery-active="false"])
    # The swapped-out macro image hides; the microscopy media is visible.
    assert_selector %([data-media-key="micro-0"]:not(.hidden))
    assert_selector %([data-media-key="macro"].hidden), visible: :all
  end

  private

  def attach_asset(material, kind:, filename:, content_type:, position: 0)
    asset = material.assets.build(kind: kind, position: position)
    asset.file.attach(
      io: file_fixture("sample-image.png").open,
      filename: filename,
      content_type: content_type
    )
    asset.save!
  end
end
