class WorkshopsController < ApplicationController
  before_action :require_login
  before_action :set_workshop, only: [ :show, :agenda ]

  def index
    @workshops = Workshop.ready_for_listing.includes(:participations)
  end

  def show
  end

  def agenda
  end

  private

  def set_workshop
    @workshop = Workshop.find_by!(slug: params[:slug])
  end
end
