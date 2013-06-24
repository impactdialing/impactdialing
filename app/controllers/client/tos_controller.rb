module Client
  class TosController < ClientController

    skip_before_filter :check_tos_accepted, :only => [:index, :create]
    skip_before_filter :check_paid, :only => [:index]

    def index
      flash_message(:warning, I18n.t(:updated_tos)) if !@account.account_after_change_in_tos?
    end

    def create
      @account.update_attributes(tos_accepted_date: Time.now)
      if @account.account_after_change_in_tos?
        flash_message(:notice, "Welcome! To get help for any page, click the Help button in the upper right corner.")
      end
      redirect_to client_root_path
    end
  end
end
