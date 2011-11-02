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
      @script = @user.account.scripts.create(params[:script])
      redirect_to @script
    end

    def show
      @script = @user.account.scripts.find(params[:id])
      render :new
    end
    
    def update      
      @script = account.scripts.find_by_id(params[:id])
      if @script.update_attributes(params[:script])
        flash_message(:notice, "Script sucessfully updated")
        redirect_to :action=>"index"          
      else
        render :action=>"new"   
      end
    end

    def destroy
      @script = @user.account.scripts.manual.find(params[:id])
      @script.update_attributes(:active => false)
      flash_message(:notice, "Script deleted")
      redirect_to client_scripts_path
    end
    
    def restore
      script = account.scripts.find_by_id(params[:script_id])
      script.restore
      script.save
      flash_message(:notice, "Script sucessfully restored")
      redirect_to :action => "deleted"
    end
  end
end
