require "set"

# Produces a reviewable Library import plan and applies it only on confirmation.
class LibrarySynchronizer
  Change = Data.define(:action, :resource, :id, :details)
  Result = Data.define(:mode, :changes) do
    def counts
      changes.group_by(&:action).transform_values(&:count)
    end
  end

  attr_reader :manifest

  def initialize(manifest: LibraryCatalog.current)
    @manifest = manifest
  end

  def call(apply: false)
    changes = plan
    apply!(changes) if apply
    Result.new(mode: apply ? "applied" : "dry-run", changes:)
  end

  def plan
    item_changes + taxonomy_changes + asset_synchronizer.plan.map do |change|
      Change.new(action: change.action, resource: change.resource, id: change.id, details: change.details)
    end
  end

  private

  def item_changes
    desired_ids = manifest.items.map(&:id)
    changes = manifest.items.filter_map do |entry|
      item = LibraryItem.find_by(slug: entry.id)
      action = item ? (item_signature(item) == entry_signature(entry) ? nil : "change") : "add"
      Change.new(action:, resource: "item", id: entry.id, details: {}) if action
    end
    LibraryItem.where(managed_by_manifest: true, published: true).where.not(slug: desired_ids).find_each do |item|
      changes << Change.new(action: "retire", resource: "item", id: item.slug, details: {})
    end
    changes
  end

  def taxonomy_changes
    desired = manifest.taxonomies.flat_map do |taxonomy|
      taxonomy.terms.map { |term| [ taxonomy.id, term ] }
    end
    identities = desired.map { |taxonomy, term| [ taxonomy, term.id ] }
    changes = desired.filter_map do |taxonomy, term|
      record = LibraryTaxonomyTerm.find_by(taxonomy_key: taxonomy, slug: term.id)
      action = if record.nil?
        "add"
      elsif record.position != term.position || record.name_translations != term.labels || !record.published?
        "change"
      end
      Change.new(action:, resource: "taxonomy_term", id: "#{taxonomy}:#{term.id}", details: {}) if action
    end
    LibraryTaxonomyTerm.where(managed_by_manifest: true, published: true).find_each do |term|
      next if identities.include?([ term.taxonomy_key, term.slug ])

      changes << Change.new(action: "retire", resource: "taxonomy_term", id: "#{term.taxonomy_key}:#{term.slug}", details: {})
    end
    changes
  end

  def apply!(changes)
    ApplicationRecord.transaction do
      LibraryItem.seed_from_manifest!(manifest:, overwrite: true)
      asset_synchronizer.apply!
      refresh_bookmarks!
    end
    changes
  end

  def refresh_bookmarks!
    LibraryItem.where(slug: manifest.items.map(&:id)).find_each do |item|
      Bookmark.where(bookmarkable_type: "LibraryItem", resource_key: item.slug)
              .where.not(label: item.title_in(LibraryItem.base_locale))
              .update_all(label: item.title_in(LibraryItem.base_locale), updated_at: Time.current)
    end
  end

  def item_signature(item)
    {
      item_type: item.item_type,
      position: item.position,
      published: item.published,
      translations: manifest_translations(item.title_translations, item.summary_translations),
      fields: item.custom_fields,
      taxonomies: item.taxonomy_terms.group_by(&:taxonomy_key).transform_values { |terms| terms.map(&:slug).sort },
      links: item.links
    }
  end

  def entry_signature(entry)
    {
      item_type: entry.item_type,
      position: entry.position,
      published: entry.published,
      translations: entry.translations,
      fields: entry.fields,
      taxonomies: entry.taxonomies.transform_values(&:sort),
      links: entry.links.map { |link| { "label" => link.label, "url" => link.url } }
    }
  end

  def manifest_translations(titles, summaries)
    (titles.keys | summaries.keys).to_h do |locale|
      [ locale, { "title" => titles[locale], "summary" => summaries[locale] } ]
    end
  end

  def asset_synchronizer
    @asset_synchronizer ||= LibraryAssetSynchronizer.new(manifest:)
  end
end
