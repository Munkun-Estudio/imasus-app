class LegalPagesController < ApplicationController
  def privacy
    render_page("privacy")
  end

  def terms
    render_page("terms")
  end

  private

  def render_page(page_key)
    @page_key = page_key
    render :show
  end
end
