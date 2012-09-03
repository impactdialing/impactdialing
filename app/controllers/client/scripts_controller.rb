module Client
  class ScriptsController < ::ScriptsController
    skip_before_filter :apply_changes, :questions_answered
    before_filter :load_voter_fields, :only => [:new, :show]

    layout 'client'

    respond_to :html
    respond_to :json, :only => [:index, :create, :show, :update, :destroy]

    def index
      respond_to do |format|
        format.html {@scripts = @user.scripts.manual.active.paginate(:page => params[:page])}
        format.json {@scripts = account.scripts.where(:active => true)}
      end
    end

    def new
      @script = Script.new(robo: false)
      @script.script_texts.new(script_order: 1)
      @question = @script.questions.new(script_order: 2)
      @question.possible_responses.new(possible_response_order: 1)
    end

    def create
      @script = account.scripts.new
      @error_action = 'new'
      save_script
    end

    def show
      load_script
    end

    def update
      load_script
      @error_action = 'show'
      save_script
    end

    def destroy
      load_script
      @script.active = false
      respond_to do |format|
        format.html do
          if @script.save
            flash_message(:notice, "Script deleted")
          else
            flash_message(:error, @script.errors.full_messages.join)
          end
          redirect_to :action => "index"
        end
        format.json {respond_with @script.save}
      end
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
      @script = account.scripts.find(params[:id])
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
      puts params
      respond_to do |format|
        format.html do
          if @script.update_attributes!(params[:script])
            flash_message(:notice, "Script saved")
            redirect_to :action=>"index"
          else
            render :action => @error_action
          end
        end
        format.json {respond_with @script.update_attributes(params[:script])}
      end
    end
  end
end
