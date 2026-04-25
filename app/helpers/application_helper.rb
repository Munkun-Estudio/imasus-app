module ApplicationHelper
  # Navigation items with their associated swatch color and IA group.
  #
  # Groups:
  #   - :hub        → Home (numbered 00)
  #   - :community  → Workshops
  #   - :resources  → Materials, Training, Challenges, Glossary
  #
  # Red is reserved as an accent and is intentionally not used in the sidebar.
  #
  # @return [Array<Hash>] nav items with :key, :path, :number, :color, :group keys
  def nav_items
    [
      { key: "home",      path: root_path,           number: "00", color: "bg-white border border-imasus-dark-green/20", group: :hub },
      { key: "workshops", path: workshops_path,      number: "01", color: "bg-imasus-dark-green",                         group: :community },
      { key: "materials", path: materials_path,      number: "02", color: "bg-imasus-light-blue",                         group: :resources },
      { key: "training",  path: training_index_path, number: "03", color: "bg-imasus-navy",                                group: :resources },
      { key: "challenges", path: challenges_path,    number: "04", color: "bg-imasus-mint",                                group: :resources },
      { key: "glossary",  path: glossary_terms_path, number: "05", color: "bg-imasus-light-pink",                          group: :resources }
    ]
  end

  # Returns CSS classes for a swatch-style navigation card.
  # Active items get a subtle ring highlight. Section roots stay active for
  # nested routes, so `/workshops/spain` still highlights Workshops.
  #
  # @example
  #   nav_swatch_classes("/materials", "bg-imasus-light-blue")
  #
  # @param path [String] the path to compare against the current request
  # @param color [String] Tailwind background class for the swatch
  # @return [String] CSS class string including "nav-active" when on that page
  def nav_swatch_classes(path, color)
    base = "#{color} block rounded-xl p-4 min-h-[4.5rem] transition-all duration-150"
    if nav_path_active?(path)
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

  # @param path [String]
  # @return [Boolean] true when the current request is inside this nav section
  def nav_path_active?(path)
    current = request.path
    return current == path if path == root_path

    current == path || current.start_with?("#{path}/")
  end
end
