module Client
  class TosController < ClientController

    skip_before_filter :check_tos_accepted, :only => [:index, :create]
    def index
    end

    def create
      @account.update_attributes(tos_accepted_date: Time.now)
      redirect_to client_root_path
    end
  end
end
