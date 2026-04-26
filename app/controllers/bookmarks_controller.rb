class BookmarksController < ApplicationController
  before_action :require_login
  before_action :set_bookmark, only: :destroy

  GROUPED_TYPES = %w[TrainingModule Material GlossaryTerm Challenge].freeze

  def index
    all = current_user.bookmarks.recent
    @grouped = GROUPED_TYPES.index_with { |type| all.select { |b| b.bookmarkable_type == type } }
  end

  def create
    @bookmark = current_user.bookmarks.find_or_initialize_by(
      bookmarkable_type: bookmark_params[:bookmarkable_type],
      resource_key:      bookmark_params[:resource_key]
    )

    if @bookmark.new_record?
      @bookmark.assign_attributes(label: bookmark_params[:label], url: bookmark_params[:url])
      @bookmark.save!
    end

    respond_to do |format|
      format.turbo_stream { render_toggle_stream(saved: true) }
      format.json { render json: { id: @bookmark.id, saved: true } }
    end
  end

  def destroy
    if @bookmark.nil?
      head :not_found
      return
    end

    @bookmark.destroy!

    respond_to do |format|
      format.turbo_stream do
        if params[:context] == "index"
          render turbo_stream: turbo_stream.remove("bookmark-row-#{@bookmark.id}")
        else
          render_toggle_stream(saved: false)
        end
      end
      format.json { render json: { saved: false } }
    end
  end

  private

  def set_bookmark
    @bookmark = current_user.bookmarks.find_by(id: params[:id])
  end

  def bookmark_params
    params.fetch(:bookmark, {}).permit(:bookmarkable_type, :resource_key, :label, :url)
  end

  def render_toggle_stream(saved:)
    type = bookmark_params[:bookmarkable_type].presence || @bookmark&.bookmarkable_type
    key  = bookmark_params[:resource_key].presence      || @bookmark&.resource_key
    did  = "bookmark-toggle-#{type.to_s.underscore}-#{key.to_s.parameterize}"

    render turbo_stream: turbo_stream.replace(
      did,
      partial: "bookmarks/toggle",
      locals:  { bookmark:          saved ? @bookmark : nil,
                 bookmarkable_type: type,
                 resource_key:      key,
                 label:             bookmark_params[:label].presence || @bookmark&.label,
                 url:               bookmark_params[:url].presence   || @bookmark&.url,
                 dom_id:            did }
    )
  end
end
