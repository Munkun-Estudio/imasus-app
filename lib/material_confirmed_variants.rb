# Material data corrections confirmed by partners during the media refresh.
#
# The production database may still contain source-document placeholder slugs
# such as `ecoalf-recycled-cotton-1-2`. This service can dry-run or apply the
# canonical split into separate visual variants while copying production-edited
# text from the existing row.
class MaterialConfirmedVariants
  VARIANT_GROUPS = [
    {
      source_slugs: [ "ecoalf-recycled-cotton-1-2", "ecoalf-recycled-cotton-1" ],
      canonical:    { slug: "ecoalf-recycled-cotton-1", trade_name: "ECOALF-Recycled cotton 1" },
      variants:     [
        { slug: "ecoalf-recycled-cotton-2", trade_name: "ECOALF-Recycled cotton 2" }
      ]
    },
    {
      source_slugs: [ "ecoalf-recycled-polyester-1-2", "ecoalf-recycled-polyester-1" ],
      canonical:    { slug: "ecoalf-recycled-polyester-1", trade_name: "ECOALF-Recycled polyester 1" },
      variants:     [
        { slug: "ecoalf-recycled-polyester-2", trade_name: "ECOALF-Recycled polyester 2" }
      ]
    },
    {
      source_slugs: [ "pyratex-upcycled-2" ],
      canonical:    { slug: "pyratex-upcycled-2", trade_name: "Pyratex upcycled 2" },
      variants:     [
        { slug: "pyratex-upcycled-5", trade_name: "Pyratex upcycled 5" }
      ]
    }
  ].freeze

  Result = Struct.new(:changes, :skips, :missing, :conflicts, keyword_init: true) do
    def summary
      "#{changes.size} change(s), #{skips.size} skip(s), " \
        "#{missing.size} missing source(s), #{conflicts.size} conflict(s)"
    end
  end

  def initialize(apply: false)
    @apply = apply
  end

  def call
    result = Result.new(changes: [], skips: [], missing: [], conflicts: [])

    ActiveRecord::Base.transaction do
      VARIANT_GROUPS.each { |group| materialize_group(group, result) }
      raise ActiveRecord::Rollback unless @apply
    end

    result
  end

  private

  def materialize_group(group, result)
    source = find_source(group)
    unless source
      result.missing << group[:source_slugs].join(" or ")
      return
    end

    canonical = group.fetch(:canonical)
    source = materialize_canonical(source, canonical, result)
    return unless source

    group.fetch(:variants).each_with_index do |variant, index|
      materialize_variant(source, variant, index + 1, result)
    end
  end

  def find_source(group)
    group.fetch(:source_slugs).filter_map { |slug| Material.find_by(slug: slug) }.first
  end

  def materialize_canonical(source, canonical, result)
    existing = Material.find_by(slug: canonical.fetch(:slug))
    if existing && existing != source
      result.conflicts << "canonical slug already exists: #{canonical.fetch(:slug)}"
      return nil
    end

    if source.slug == canonical.fetch(:slug) && source.trade_name == canonical.fetch(:trade_name)
      result.skips << "canonical already present: #{canonical.fetch(:slug)}"
      return source
    end

    result.changes << "rename #{source.slug} -> #{canonical.fetch(:slug)} (#{canonical.fetch(:trade_name)})"
    return source unless @apply

    source.update!(slug: canonical.fetch(:slug), trade_name: canonical.fetch(:trade_name))
    source
  end

  def materialize_variant(source, variant, offset, result)
    existing = Material.find_by(slug: variant.fetch(:slug))
    if existing
      result.skips << "variant already present: #{variant.fetch(:slug)}"
      return existing
    end

    result.changes << "clone #{source.slug} -> #{variant.fetch(:slug)} (#{variant.fetch(:trade_name)})"
    return unless @apply

    clone = source.dup
    clone.slug = variant.fetch(:slug)
    clone.trade_name = variant.fetch(:trade_name)
    clone.position = source.position.to_i + offset
    clone.save!
    clone.tag_ids = source.tag_ids
    clone
  end
end
