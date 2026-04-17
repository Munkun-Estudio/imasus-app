module ApplicationHelper
  # Navigation items with their associated swatch color.
  # Each item maps to a brand palette color, creating a paint-chip aesthetic.
  #
  # @return [Array<Hash>] nav items with :key, :path, :number, :color keys
  def nav_items
    [
      { key: "home",      path: root_path,            number: "00", color: "bg-white border border-imasus-dark-green/20" },
      { key: "materials",  path: materials_path,       number: "01", color: "bg-imasus-red" },
      { key: "training",   path: training_index_path,  number: "02", color: "bg-imasus-navy" },
      { key: "workshops",  path: workshops_path,       number: "03", color: "bg-imasus-dark-green" },
      { key: "log",        path: log_index_path,       number: "04", color: "bg-imasus-light-blue" },
      { key: "prototype",  path: prototype_index_path, number: "05", color: "bg-imasus-mint" },
      { key: "glossary",   path: glossary_terms_path,  number: "06", color: "bg-imasus-light-pink" }
    ]
  end

  # Returns CSS classes for a swatch-style navigation card.
  # Active items get a subtle ring highlight.
  #
  # @example
  #   nav_swatch_classes("/materials", "bg-imasus-red")
  #
  # @param path [String] the path to compare against the current request
  # @param color [String] Tailwind background class for the swatch
  # @return [String] CSS class string including "nav-active" when on that page
  def nav_swatch_classes(path, color)
    base = "#{color} block rounded-xl p-4 min-h-[4.5rem] transition-all duration-150"
    if current_page?(path)
      "#{base} nav-active ring-2 ring-imasus-dark-green ring-offset-2"
    else
      "#{base} hover:scale-[1.03] hover:shadow-md"
    end
  end

  # Whether a swatch nav item should use light text (for dark backgrounds).
  #
  # @param color [String] Tailwind background class
  # @return [Boolean]
  def swatch_dark_bg?(color)
    color.match?(/bg-imasus-(red|navy|dark-green)\b/)
  end
end
