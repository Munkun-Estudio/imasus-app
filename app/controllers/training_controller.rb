class TrainingController < ApplicationController
  def index
    @loader = TrainingModule::Loader.new
    @modules = @loader.all
    @about = @loader.about(I18n.locale.to_s)
  end

  def show
    loader = TrainingModule::Loader.new
    @section = loader.section(params[:slug], params[:section], I18n.locale.to_s)

    if @section.nil?
      render file: Rails.root.join("public/404.html"), status: :not_found, layout: false
      return
    end

    @rendered_body  = TrainingModule::Renderer.call(@section.body)
    @saved_training = saved_training_bookmarks(@section)

    sections = @section.available_sections
    current_index = sections.index(@section.volume)
    @previous_section = current_index && current_index > 0 ? sections[current_index - 1] : nil
    @next_section = current_index && current_index < sections.size - 1 ? sections[current_index + 1] : nil
  end

  private

  # Returns a JSON-safe hash of { resource_key => bookmark_id } for all
  # TrainingModule bookmarks the current user has saved in this section.
  # Used by the training-bookmark Stimulus controller to render initial state.
  def saved_training_bookmarks(section)
    return {} unless logged_in?

    prefix = "#{section.module_slug}/#{section.volume}/#{I18n.locale}"
    current_user.bookmarks
                .by_type("TrainingModule")
                .where("resource_key LIKE ?", "#{prefix}/%")
                .pluck(:resource_key, :id)
                .to_h
  end
end
