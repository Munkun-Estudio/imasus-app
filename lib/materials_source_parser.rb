# Parses the hand-authored `docs/materials-db.md` source document into the
# structured hash shape consumed by `Material.seed_from_yaml!`.
#
# The source document is authored by researchers, not code. It drifts in
# punctuation, capitalisation, and occasional typos. The parser is deliberately
# tolerant: it extracts what it can, leaves ambiguous prose (e.g. sensorial
# qualities, which sit in unlabeled paragraphs) for a follow-up content pass,
# and normalises the origin / textile-imitating / application vocabularies into
# the canonical tag slugs used by `db/seeds/material_tags.yml`.
#
# Usage:
#
#   source = File.read("docs/materials-db.md")
#   entries = MaterialsSourceParser.new(source).entries
#   File.write("db/seeds/materials.yml", entries.to_yaml(line_width: -1))
class MaterialsSourceParser
  # Maps raw `Origin:` field values (lower-cased, hyphens trimmed) to canonical
  # origin_type tag slugs. Order matters: longer/more-specific prefixes first.
  ORIGIN_NORMALIZATIONS = [
    [ /mycelium/,           "fungi" ],
    [ /\bfungi?\b|mushroom/, "fungi" ],
    [ /spider/,             "animals" ],
    [ /\bmilk\b/,           "animals" ],
    [ /cow.?gut|collagen/,  "animals" ],
    [ /crab|shell|chitosan/, "animals" ],
    [ /\banimal/,           "animals" ],
    [ /bacteri/,            "bacteria" ],
    [ /microbial/,          "microbial" ],
    [ /\bprotein\b/,        "protein" ],
    [ /seaweed|algae/,      "seaweed" ],
    [ /tyre|tire/,          "recycled_materials" ],
    [ /petroleum|plastic bottle/, "recycled_materials" ],
    [ /textile waste/,      "recycled_materials" ],
    [ /old wool/,           "recycled_materials" ],
    [ /recycle/,            "recycled_materials" ],
    [ /fishing net/,        "recycled_materials" ],
    [ /wood(en)? pulp|paper|soy|coffee?\b|banana|pineapple|potato|grape|orange|cotton|hemp|bamboo|kapok|nettle|cypress|abaca|tree|flax|linen|ceiba|plant/, "plants" ]
  ].freeze

  TEXTILE_NORMALIZATIONS = [
    [ /\bleather\b/,                        "leather" ],
    [ /\bdenim\b/,                          "denim" ],
    [ /spider silk|\bsilk\b/,               "silk" ],
    [ /\bwool\b/,                           "wool" ],
    [ /\bfelt\b/,                           "felt" ],
    [ /mesh/,                               "mesh" ],
    [ /conventional cotton|\bcotton\b/,     "conventional_cotton" ],
    [ /conventional linen|\blinen\b/,       "conventional_linen" ],
    [ /conventional nylon|\bnylon\b/,       "conventional_nylon" ],
    [ /conventional polyester|\bpolyester\b/, "conventional_polyester" ],
    [ /synthetic fib(re|er)s?/,             "synthetic_fibres" ],
    [ /synthetic rubber/,                   "synthetic_rubber" ]
  ].freeze

  # Application patterns are scanned for ALL matches per bullet. Multi-match is
  # expected: a bullet like "Footwear and accessories" should yield both slugs.
  APPLICATION_NORMALIZATIONS = [
    [ /safety equipment|life.?vest|life.?jacket|\bPPE\b|industrial.*safet/i, "safety_equipment" ],
    [ /automotive|vehicle interior/i, "automotive" ],
    [ /technical textile|technical garment|high.?performance|sport sector|sports sector|\bcarpet|\brug/i, "technical_textiles" ],
    [ /\bfilling\b|stuffing/i,        "filling" ],
    [ /furniture|\bchair|soft furnishing|interior design:/i, "furniture" ],
    [ /home textile|home decor|home and interior|housewear|cushion cover|curtain|\bthrow(s|)|lamp cover|\bdecor\b/i, "home_textiles" ],
    [ /footwear|sneaker|\bboot|trainer|sandal/i, "footwear" ],
    [ /accessor|\bbag\b|\bbelt\b|wallet|scarf|scarves|\bhat\b|backpack|\bstrap|\bpouch|sleeve|handbag/i, "accessories" ],
    [ /\bart\b|performance|installation/i, "art" ],
    [ /clothing|\bclothes\b|garment|jacket|raincoat|outerwear|swimwear|apparel|wearable|\btrim\b|sustainable fashion|loungewear|luxury fashion|baby clothing|fashion accessor|designer fashion|activewear/i, "clothing" ]
  ].freeze

  AVAILABILITY_HEURISTICS = [
    [ /\buniversity\b|zaragoza|horizon 2020|research project|design research project|my-fi project/i, "research_only" ],
    [ /not available|no samples available|work in progress|currently unavailable|\bpilot stage\b|still in progress|availability:\s*no\b|availability:\s*-?\s*$|availability:\s*-?\s*unknown/i, "in_development" ]
  ].freeze

  # @param source [String] the full contents of `docs/materials-db.md`
  def initialize(source)
    @source = source
  end

  # @return [Array<Hash>] one entry per material, ready to `to_yaml`.
  #
  # When the source lists the same product under two origin headings — as the
  # SMEs sometimes do for discoverability (e.g. Pyratex Seacell 7 appears
  # under both Bamboo and Seaweed) — the duplicate entries are **merged**: the
  # first occurrence keeps its narrative fields and the later occurrences' tag
  # lists are unioned in, so the resulting row carries every relevant origin
  # tag. Slugs therefore stay trade-name-unique.
  def entries
    by_slug = {}
    ordered = []

    split_into_entries.each do |chunk|
      entry = parse_entry(chunk)
      entry["slug"] = entry["trade_name"].parameterize

      if (existing = by_slug[entry["slug"]])
        merge_entries!(existing, entry)
      else
        by_slug[entry["slug"]] = entry
        ordered << entry
      end
    end

    ordered
  end

  private

  Chunk = Struct.new(:material_of_origin, :trade_name, :body, keyword_init: true)

  # Unions tag lists across facets from `incoming` into `existing`. Non-tag
  # fields on `existing` win: the first occurrence is the canonical narrative.
  def merge_entries!(existing, incoming)
    existing["tags"] ||= {}
    (incoming["tags"] || {}).each do |facet, slugs|
      existing["tags"][facet] = ((existing["tags"][facet] || []) + Array(slugs)).uniq
    end
  end

  def split_into_entries
    current_group = nil
    chunks = []
    current_entry_lines = nil
    current_trade_name = nil

    @source.each_line do |line|
      if (match = line.match(/^##\s+\*\*(?<heading>[^*]+?)\*\*\s*\{/))
        flush(chunks, current_group, current_trade_name, current_entry_lines) if current_entry_lines
        current_group = clean_inline(match[:heading])
        current_entry_lines = nil
        current_trade_name = nil
      elsif (match = line.match(/^\*\s+###\s+(?<name>.+?)\s*\{/))
        flush(chunks, current_group, current_trade_name, current_entry_lines) if current_entry_lines
        current_trade_name = clean_inline(match[:name])
        current_entry_lines = []
      elsif current_entry_lines
        current_entry_lines << line
      end
    end

    flush(chunks, current_group, current_trade_name, current_entry_lines) if current_entry_lines
    chunks
  end

  def flush(chunks, group, name, lines)
    return unless group && name && lines

    chunks << Chunk.new(material_of_origin: group, trade_name: name, body: lines.join)
  end

  def parse_entry(chunk)
    fields = extract_fields(chunk.body)

    entry = {
      "trade_name"          => chunk.trade_name,
      "material_of_origin"  => chunk.material_of_origin,
      "availability_status" => infer_availability(fields, chunk.body),
      "description"         => locale_string(fields["description"]),
      "interesting_properties" => locale_string(fields["interesting facts"]),
      "structure"           => locale_string(fields["structure"]),
      "what_problem_it_solves" => locale_string(fields["what problem it solves"]),
      "sensorial_qualities" => {}, # parked for a follow-up content pass
      "tags"                => derive_tags(fields)
    }

    if (supplier_url = extract_url(fields["availability"]))
      entry["supplier_url"] = supplier_url
    end

    if (supplier_name = derive_supplier_name(fields["availability"]))
      entry["supplier_name"] = supplier_name
    end

    entry.compact
  end

  LABEL_REGEX = /\*\*\s*(?<label>[A-Za-z][A-Za-z ]+?)\s*:?\s*x?\s*\*\*\s*:?/i

  KNOWN_LABELS = %w[
    subtypes origin textile\ imitating possible\ applications availability
    description interesting\ facts structure retails what\ problem\ it\ solves
  ].freeze

  def extract_fields(body)
    fields = Hash.new { |h, k| h[k] = +"" }
    current_label = nil
    inline_buffer = nil

    body.each_line do |line|
      stripped = line.chomp

      if (match = stripped.match(/\A\s*\*\*(?<label>[A-Za-z][A-Za-z ]*?)\s*:?\*\*\s*:?\s*(?<rest>.*)\z/))
        label = normalise_label(match[:label])
        if label
          current_label = label
          rest = match[:rest].to_s
          fields[current_label] << rest << "\n" unless rest.empty?
          next
        end
      end

      fields[current_label] << stripped << "\n" if current_label
    end

    fields.each_value(&:strip!)
    fields
  end

  def normalise_label(raw)
    cleaned = raw.downcase.strip.gsub(/\s+/, " ")
    KNOWN_LABELS.include?(cleaned) ? cleaned : nil
  end

  def clean_inline(text)
    text.to_s
        .gsub(/\\-/, "-")
        .gsub(/\\_/, "_")
        .gsub(/\{#.*?\}/, "")
        .gsub(/\s+/, " ")
        .strip
  end

  def locale_string(raw)
    value = clean_prose(raw)
    value.present? ? { "en" => value } : {}
  end

  def clean_prose(raw)
    return "" if raw.nil? || raw.strip.empty?

    cleaned = raw.dup
    cleaned = cleaned.gsub(/\\-/, "-").gsub(/\\_/, "_").gsub(/\\\\/, "\\")
    cleaned = cleaned.gsub(/\*\*\s*\*\*/, "")         # stray double-bold
    cleaned = cleaned.gsub(/(?<=\s)-\s*(?=\S)/, "")   # leading "- " on lines
    cleaned = cleaned.gsub(/\A-\s*/, "")
    cleaned = cleaned.gsub(/\r/, "")
    cleaned = cleaned.split(/\n\s*\n/).map { |para| para.gsub(/\s+/, " ").strip }.reject(&:empty?).join("\n\n")
    cleaned.strip
  end

  def infer_availability(fields, body)
    availability_text = fields["availability"].to_s
    context_text      = [ fields["retails"], fields["interesting facts"], body ].compact.join("\n")

    # `research_only` takes priority when the material is university-led or
    # part of a publicly-funded research project — these rarely turn into
    # purchasable stock even when the source notes a pilot availability.
    AVAILABILITY_HEURISTICS.each do |pattern, status|
      return status if status == "research_only" && context_text.match?(pattern)
    end

    AVAILABILITY_HEURISTICS.each do |pattern, status|
      return status if [ availability_text, context_text ].any? { |t| t.match?(pattern) }
    end

    "commercial"
  end

  def extract_url(raw_availability)
    return nil if raw_availability.nil?

    match = raw_availability.match(%r{https?://\S+}i)
    return nil unless match

    url = match[0]
    url = url.sub(/[.,;)\]]+\z/, "")    # drop trailing punctuation
    url = url.sub(/\\#attr.*\z/, "")    # drop escaped #attr= anchors
    url = url.sub(/#attr.*\z/, "")      # drop #attr= anchors
    url = url.sub(/\]\(.*\z/, "")       # strip markdown-link tail if any leaked
    url.presence
  end

  def derive_supplier_name(raw_availability)
    return nil if raw_availability.nil?

    first_line = raw_availability.lines.first.to_s.strip
    first_line = first_line.sub(/\A-\s*/, "").sub(/\Ahttps?:.*\z/i, "")
    return nil if first_line.empty? || first_line.start_with?("http")
    return nil if first_line.match?(/\Ano\z|\Anot available\z/i)

    first_line.sub(/\s+https?:.*\z/i, "").strip.presence
  end

  def derive_tags(fields)
    tags = {}

    origin_tag = match_vocabulary(fields["origin"], ORIGIN_NORMALIZATIONS)
    tags["origin_type"] = [ origin_tag ] if origin_tag

    textile_tag = match_vocabulary(fields["textile imitating"], TEXTILE_NORMALIZATIONS)
    tags["textile_imitating"] = [ textile_tag ] if textile_tag

    apps = derive_application_tags(fields["possible applications"])
    tags["application"] = apps if apps.any?

    tags
  end

  def match_vocabulary(raw, table)
    return nil if raw.nil? || raw.strip.empty? || raw.match?(/unknown|unknow\b|\Aunknow/i)

    text = raw.downcase
    table.each do |pattern, slug|
      return slug if text.match?(pattern)
    end

    nil
  end

  def derive_application_tags(raw)
    return [] if raw.nil? || raw.strip.empty?

    bullets = raw.each_line.filter_map do |line|
      next unless line =~ /^\s*[*-]\s*(.+)/

      bullet = $1.strip
      bullet.empty? || bullet.match?(/\Aunknown\b|\Aunknow\b/i) ? nil : bullet
    end

    bullets.flat_map { |bullet| match_all_vocabulary(bullet, APPLICATION_NORMALIZATIONS) }.uniq
  end

  def match_all_vocabulary(raw, table)
    return [] if raw.nil? || raw.strip.empty?

    text = raw.downcase
    table.filter_map { |pattern, slug| slug if text.match?(pattern) }
  end
end
