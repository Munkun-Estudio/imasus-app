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

    @rendered_body = TrainingModule::Renderer.call(@section.body)

    sections = @section.available_sections
    current_index = sections.index(@section.volume)
    @previous_section = current_index && current_index > 0 ? sections[current_index - 1] : nil
    @next_section = current_index && current_index < sections.size - 1 ? sections[current_index + 1] : nil
  end
end
