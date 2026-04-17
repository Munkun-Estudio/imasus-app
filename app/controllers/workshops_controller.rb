class WorkshopsController < ApplicationController
  before_action :require_login, only: :show

  def index
  end

  def show
    @workshop = Workshop.find(params[:id])
  end
end
