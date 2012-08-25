module Client
  class ScriptsController < ::ScriptsController
    skip_before_filter :apply_changes, :questions_answered
    before_filter :load_script, :only => [:show, :update, :destroy]
    before_filter :load_voter_fields, :only => [:new, :show]

    layout 'client'

    def index
      @scripts = @user.scripts.manual.active.paginate(:page => params[:page])
    end

    def new
      @script = Script.new(robo: false,
                           questions: [Question.new(possible_responses: [PossibleResponse.new])],
                           script_texts: [ScriptText.new])
    end

    def create
      @script = account.scripts.new
      @error_action = 'new'
      save_script
    end

    def show
    end

    def update
      @error_action = 'show'
      save_script
    end

    def destroy
      if @user.account.campaigns.active.find_by_script_id(@script.id).nil?
        @script.update_attributes(:active => false)
        flash_message(:notice, "Script deleted")
      else
        flash_message(:notice, I18n.t(:script_cannot_be_deleted))
      end
      redirect_to :action => "index"
    end

    def questions_answered
      render :json => { :data => Question.question_count_script(params[:id]) }
    end

    def possible_responses_answered
      render :json => { :data => PossibleResponse.possible_response_count(params[:question_ids]) }
    end

    def deleted
      render 'scripts/deleted'
    end

    def load_deleted
      self.instance_variable_set("@#{type_name.pluralize}", Script.deleted.for_account(@user.account).paginate(:page => params[:page], :order => 'id desc'))
    end

    private

    def load_script
      @script = Script.find(params[:id])
    end

    def load_voter_fields
      @voter_fields = VoterList::VOTER_DATA_COLUMNS.values
      @voter_fields.concat(@user.account.custom_voter_fields.collect{ |field| field.name})
      if @script.voter_fields!=nil
        begin
          @voter_field_values = JSON.parse(@script.voter_fields)
        rescue
          @voter_field_values=[]
        end
      else
        @voter_field_values=[]
      end
    end

    def save_script
      params[:script][:voter_fields] =  params[:voter_field] ? params[:voter_field].to_json : nil
      if @script.update_attributes(params[:script])
        flash_message(:notice, "Script saved")
        redirect_to :action=>"index"
      else
        render :action => @error_action
      end
    end
  end
end
