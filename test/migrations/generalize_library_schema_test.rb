require "test_helper"
require Rails.root.join("db/migrate/20260718140000_generalize_library_schema")

class GeneralizeLibrarySchemaTest < ActiveSupport::TestCase
  test "migrates Material bookmarks to stable Library slugs and restores numeric keys" do
    user = User.create!(
      name: "Migration bookmark",
      email: "library-migration-bookmark@example.com",
      password: "correcthorsebatterystaple",
      role: :participant
    )
    material = Material.create!(
      trade_name: "Stable identity",
      availability_status: :commercial,
      description_translations: { "en" => "Stable summary" }
    )
    bookmark = Bookmark.create!(
      user:,
      bookmarkable_type: "Material",
      resource_key: material.id.to_s,
      label: material.trade_name,
      url: "/materials/#{material.slug}"
    )

    migration = GeneralizeLibrarySchema.new
    migration.send(:migrate_bookmarks_to_stable_identity)
    assert_equal [ "LibraryItem", material.slug ], bookmark.reload.values_at(:bookmarkable_type, :resource_key)

    migration.send(:migrate_bookmarks_to_legacy_identity)
    assert_equal [ "Material", material.id.to_s ], bookmark.reload.values_at(:bookmarkable_type, :resource_key)
  end

  test "copies attachment aliases without copying blobs and remains idempotent" do
    material = Material.create!(
      trade_name: "Attachment identity",
      availability_status: :commercial,
      description_translations: { "en" => "Attachment summary" }
    )
    asset = MaterialAsset.new(material:, kind: :macro, position: 0)
    asset.file.attach(io: StringIO.new("image"), filename: "image.jpg", content_type: "image/jpeg")
    asset.save!
    generic = asset.file_attachment
    ActiveStorage::Attachment.create!(
      name: generic.name,
      record_type: "MaterialAsset",
      record_id: generic.record_id,
      blob_id: generic.blob_id,
      created_at: generic.created_at
    )
    generic.delete

    migration = GeneralizeLibrarySchema.new
    2.times { migration.send(:copy_asset_attachments, "MaterialAsset", "LibraryItemAsset") }

    aliases = ActiveStorage::Attachment.where(record_id: asset.id, name: "file")
    assert_equal %w[LibraryItemAsset MaterialAsset], aliases.order(:record_type).pluck(:record_type)
    assert_equal 1, aliases.distinct.count(:blob_id)
  end

  test "refuses a lossy rollback after a generic item type has been added" do
    LibraryItem.insert_all!([
      {
        slug: "generic-worksheet",
        item_type: "worksheet",
        title_translations: { "en" => "Worksheet" },
        summary_translations: { "en" => "Cannot fit the old schema" },
        custom_fields: {},
        links: [],
        created_at: Time.current,
        updated_at: Time.current
      }
    ])

    error = assert_raises(ActiveRecord::IrreversibleMigration) do
      GeneralizeLibrarySchema.new.send(:assert_legacy_rollback_is_safe!)
    end
    assert_includes error.message, "1 non-material items"
  end
end
