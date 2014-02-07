module Client
  class TosController < ClientController

    skip_before_filter :check_login, :only => [:policies]
    skip_before_filter :authenticate_api, :only => [:policies]
    skip_before_filter :check_credit_card_declined, :only => [:policies]
    skip_before_filter :check_tos_accepted, :only => [:index, :create, :policies]
    skip_before_filter :check_paid, :only => [:index, :policies]

    def index
      flash_message(:warning, I18n.t(:updated_tos)) if !@account.account_after_change_in_tos?
    end

    def create
      @account.update_attributes(tos_accepted_date: Time.now)
      if @account.account_after_change_in_tos?
        flash_message(:notice, "Welcome! To get help for any page, click the Help button in the upper right corner.")
        billing_link = '<a href="' + white_labeled_billing_link(request.domain) + '">upgrade your account</a>'
        flash_message(:notice, I18n.t(:enjoy_the_trial, billing_link: billing_link).html_safe)
      end
      redirect_to client_root_path
    end
  end
end
