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
      params[:script][:voter_fields] = params[:voter_fields].to_json
      @script = Script.new(params[:script])  
      @voter_field_values = params[:voter_fields] || []
      if @script.save
        @user.account.scripts << @script
        flash_message(:notice, "Script saved")
        redirect_to :action=>"index"          
      else
        render :action=>"new"   
      end
    end

    def show
      @script = @user.account.scripts.find(params[:id])
      @script.questions << [Question.new(possible_responses: [PossibleResponse.new])]  if @script.questions.empty?
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
      params[:script][:voter_fields] =  params[:voter_field] ? params[:voter_field].to_json : nil
      if @script.update_attributes(params[:script])
        flash_message(:notice, "Script updated")
        redirect_to :action=>"index"          
      else
        render :action=>"new"   
      end
    end

    def destroy
      @script = @user.account.scripts.manual.find(params[:id])
      @script.update_attributes(:active => false)
      flash_message(:notice, "Script deleted")
      redirect_to :action => "index"
    end
    
  end
end
