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
      @script = Script.new(:robo => false, questions: [Question.new(possible_responses: [PossibleResponse.new])])
      @voter_field_values=[]
    end

    def create
      params[:script][:voter_fields] = params[:voter_field].to_json
      @script = @user.account.scripts.create(params[:script])
      redirect_to @script
    end

    def show
      @script = @user.account.scripts.find(params[:id])
      if @script.voter_fields!=nil
        begin
          @voter_field_values = eval(@script.voter_fields)
        rescue
          @voter_field_values=[]
        end
      else
        @voter_field_values=[]
      end
      render :new
    end
    
    def update      
      @script = account.scripts.find_by_id(params[:id])
      params[:script][:voter_fields] =  params[:voter_fields].to_json
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
