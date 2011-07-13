class ReportsController < ApplicationController
  layout 'v2'

  def index
    @campaigns = Campaign.active
  end

end
