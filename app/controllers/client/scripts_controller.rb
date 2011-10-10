module Client
  class ScriptsController < ::ScriptsController
    skip_before_filter :load_script, :apply_changes

    layout 'client'

    def deleted
      render 'scripts/deleted'
    end

    def index
      @scripts = @user.scripts.manual.active.paginate(:page => params[:page])
    end

    def new
      @script = Script.new(:robo => false)
    end

    def create
      @script = @user.scripts.create(params[:script])
      redirect_to @script
    end

    def show

    end

    def destroy
      @script = @user.account.scripts.manual.find(params[:id])
      @script.update_attributes(:active => false)
      flash_message(:notice, "Script deleted")
      redirect_to client_scripts_path
    end
  end
end
