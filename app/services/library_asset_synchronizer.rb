require "digest"
require "marcel"
require "set"

# Plans and applies manifest-managed Library attachments without deleting blobs.
class LibraryAssetSynchronizer
  Change = Data.define(:action, :resource, :id, :details)

  attr_reader :manifest

  def initialize(manifest: LibraryCatalog.current)
    @manifest = manifest
  end

  def plan
    desired_changes + retirement_changes
  end

  def apply!
    changes = plan
    ApplicationRecord.transaction do
      manifest.items.each { |entry| sync_item!(entry) }
      retire_missing!
    end
    changes
  end

  private

  def desired_changes
    manifest.items.flat_map do |entry|
      item = LibraryItem.find_by(slug: entry.id)
      entry.assets.map.with_index do |asset, index|
        inspect_source!(entry, asset)
        identity = source_identity(asset)
        record = item&.assets&.unscope(where: :retired_at)&.find_by(role: asset.role, source_path: identity)
        position = entry.assets.first(index).count { |candidate| candidate.role == asset.role }
        action = record ? (asset_changed?(record, asset, position) ? "change" : nil) : "add"
        Change.new(action:, resource: "asset", id: "#{entry.id}:#{asset.role}:#{identity}", details: {}) if action
      end
    end.compact
  end

  def retirement_changes
    desired = manifest.items.to_h do |entry|
      [ entry.id, entry.assets.map { |asset| [ asset.role, source_identity(asset) ] }.to_set ]
    end
    LibraryItemAsset.where(managed_by_manifest: true, retired_at: nil).includes(:library_item).filter_map do |asset|
      identities = desired.fetch(asset.library_item.slug, Set.new)
      next if identities.include?([ asset.role, asset.source_path ])

      Change.new(action: "retire", resource: "asset", id: asset_identity(asset), details: {})
    end
  end

  def sync_item!(entry)
    item = LibraryItem.find_by!(slug: entry.id)
    positions = Hash.new(0)
    entry.assets.each do |asset|
      identity = source_identity(asset)
      record = LibraryItemAsset.unscoped.find_or_initialize_by(
        library_item_id: item.id,
        role: asset.role,
        source_path: identity
      )
      checksum = checksum_for(asset.path)
      record.validation_manifest = manifest
      record.position = positions[asset.role]
      positions[asset.role] += 1
      record.alt_text_translations = asset.alt
      record.source_checksum = checksum
      record.managed_by_manifest = true
      record.retired_at = nil
      attach_file!(record, asset.path) unless record.file.attached? && record.source_checksum_was == checksum
      record.save!
    end
  end

  def retire_missing!
    desired = manifest.items.to_h do |entry|
      [ entry.id, entry.assets.map { |asset| [ asset.role, source_identity(asset) ] }.to_set ]
    end
    LibraryItemAsset.where(managed_by_manifest: true, retired_at: nil).includes(:library_item).find_each do |asset|
      next if desired.fetch(asset.library_item.slug, Set.new).include?([ asset.role, asset.source_path ])

      asset.update_columns(retired_at: Time.current, updated_at: Time.current)
    end
  end

  def attach_file!(record, path)
    content_type = Marcel::MimeType.for(path, name: path.basename.to_s)
    definition = manifest.item_type(record.library_item.item_type).media_role(record.role)
    unless definition.allowed_types.include?(content_type)
      raise LibraryCatalog::Manifest::Error,
            "#{source_identity_from_path(path)} has detected MIME type #{content_type}; expected #{definition.allowed_types.join(', ')}"
    end
    if path.size > definition.max_bytes
      raise LibraryCatalog::Manifest::Error,
            "#{source_identity_from_path(path)} is #{path.size} bytes; maximum is #{definition.max_bytes}"
    end

    blob = path.open("rb") do |file|
      ActiveStorage::Blob.create_and_upload!(
        io: file,
        filename: path.basename.to_s,
        content_type:,
        identify: false
      )
    end
    record.file.attach(blob)
  end

  def inspect_source!(entry, asset)
    definition = manifest.item_type(entry.item_type).media_role(asset.role)
    content_type = Marcel::MimeType.for(asset.path, name: asset.path.basename.to_s)
    unless definition.allowed_types.include?(content_type)
      raise LibraryCatalog::Manifest::Error,
            "#{source_identity(asset)} has detected MIME type #{content_type}; expected #{definition.allowed_types.join(', ')}"
    end
    if asset.path.size > definition.max_bytes
      raise LibraryCatalog::Manifest::Error,
            "#{source_identity(asset)} is #{asset.path.size} bytes; maximum is #{definition.max_bytes}"
    end
  end

  def asset_changed?(record, asset, position)
    record.retired_at.present? || record.position != position ||
      record.alt_text_translations != asset.alt || record.source_checksum != checksum_for(asset.path) ||
      !record.file.attached?
  end

  def source_identity(asset)
    source_identity_from_path(asset.path)
  end

  def source_identity_from_path(path)
    path.relative_path_from(manifest.path.dirname).to_s
  end

  def checksum_for(path)
    Digest::SHA256.file(path).hexdigest
  end

  def asset_identity(asset)
    "#{asset.library_item.slug}:#{asset.role}:#{asset.source_path}"
  end
end
