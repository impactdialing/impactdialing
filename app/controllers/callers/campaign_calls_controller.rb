module Callers
  class CampaignCallsController < ::CallerController
    include ActionView::Helpers::NumberHelper
    respond_to :json, :html

    skip_before_filter :verify_authenticity_token, only: [:call_station]

private
    def current_ability
      @current_ability ||= Ability.new(@caller.account)
    end

public
    def show
      redirect_to callveyor_path and return
    end

    def script
      head 200 and return
    end

    def token
      head 200 and return
    end
  end
end
