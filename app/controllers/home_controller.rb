class HomeController < ApplicationController
  def index
    redirect_to :controller=>"client"
  end
end
