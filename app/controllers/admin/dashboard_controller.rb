class Admin::DashboardController < ApplicationController
  before_action -> { require_role :admin }

  def index
  end
end
