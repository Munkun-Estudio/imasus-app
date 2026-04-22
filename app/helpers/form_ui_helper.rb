module FormUiHelper
  PARTICIPANT_COUNTRY_OPTIONS = [
    [ "Spain", "Spain" ],
    [ "Italy", "Italy" ],
    [ "Greece", "Greece" ]
  ].freeze

  # @return [String] container classes for a centered form page
  def form_page_classes
    "px-4 py-12 sm:px-6 lg:px-8"
  end

  # @return [String] card classes for auth/admin forms
  def form_card_classes
    "mx-auto max-w-2xl rounded-[2rem] border border-imasus-dark-green/10 bg-white px-7 py-8 shadow-sm"
  end

  # @return [String] label classes shared by text inputs and textareas
  def form_label_classes
    "mb-2 block text-sm font-semibold text-imasus-dark-green"
  end

  # @param readonly [Boolean]
  # @return [String] input classes with explicit border/background/text colors
  def form_input_classes(readonly: false)
    classes = [
      "block w-full rounded-2xl border border-imasus-dark-green/15 bg-white px-4 py-3",
      "text-base text-imasus-dark-green placeholder:text-imasus-dark-green/35",
      "shadow-xs outline-none transition focus:border-imasus-dark-green focus:ring-2 focus:ring-imasus-mint/60"
    ]
    classes << "bg-stone-100 text-imasus-dark-green/60" if readonly
    classes.join(" ")
  end

  # @return [String] textarea classes
  def form_textarea_classes
    "#{form_input_classes} min-h-32 resize-y"
  end

  # @return [String] primary submit/button classes
  def form_primary_button_classes
    "inline-flex items-center justify-center rounded-full bg-imasus-dark-green px-5 py-3 text-sm font-semibold text-white transition hover:bg-imasus-navy focus:outline-none focus:ring-2 focus:ring-imasus-mint/70"
  end

  # @return [String] secondary text-link classes
  def form_secondary_link_classes
    "text-sm font-semibold text-imasus-red hover:text-imasus-dark-green hover:underline"
  end

  # @return [String] alert box classes for validation or flash errors
  def form_error_box_classes
    "mb-6 rounded-2xl border border-imasus-red/15 bg-imasus-light-pink/35 px-4 py-3 text-sm text-imasus-dark-green"
  end

  # @return [Array<Array(String, String)>] translated labels with canonical values
  def participant_country_options
    PARTICIPANT_COUNTRY_OPTIONS.map do |value, key|
      [ t("participant_invitations.edit.countries.#{key.downcase}", default: value), value ]
    end
  end

  # @param text [String] label text
  # @param tooltip [String] contextual guidance text
  # @return [ActiveSupport::SafeBuffer] styled label with hover/focus tooltip
  def form_label_with_tooltip(text, tooltip)
    content_tag(:div, class: "mb-2 flex items-center gap-2") do
      safe_join([
        content_tag(:span, text, class: "block text-sm font-semibold text-imasus-dark-green"),
        content_tag(:span, class: "group relative inline-flex items-center") do
          safe_join([
            content_tag(:button,
              heroicon(:information_circle, class: "h-4 w-4 text-imasus-dark-green/45 transition group-hover:text-imasus-dark-green"),
              type: "button",
              class: "inline-flex h-5 w-5 items-center justify-center rounded-full text-imasus-dark-green/45 hover:text-imasus-dark-green focus:outline-none focus:ring-2 focus:ring-imasus-mint/70",
              "aria-label": tooltip
            ),
            content_tag(:span,
              tooltip,
              class: "pointer-events-none absolute left-0 top-7 z-10 w-64 rounded-xl border border-imasus-dark-green/10 bg-white px-3 py-2 text-sm font-normal leading-6 text-stone-700 opacity-0 shadow-sm transition duration-150 group-hover:opacity-100 group-focus-within:opacity-100"
            )
          ])
        end
      ])
    end
  end
end
