module Client
  class ScriptsController < ::ScriptsController
    skip_before_filter :apply_changes, :questions_answered
    before_filter :load_voter_fields, :only => [:new, :show]

    layout 'client'

    respond_to :html, :json

    def index
      respond_to do |format|
        format.html {@scripts = account.scripts.manual.active.paginate(:page => params[:page])}
        format.json {respond_with account.scripts.manual.active}
      end
    end

    def new
      new_script
      @script.script_texts.new(script_order: 1)
      @question = @script.questions.new(script_order: 2)
      @question.possible_responses.new(possible_response_order: 1)
      respond_with @script
    end

    def create
      new_script
      save_script
    end

    def show
      load_script
      respond_to do |format|
        format.html {redirect_to edit_client_script_path(@script)}
        format.json {respond_with @script}
      end
    end

    def edit
      load_script
      respond_with @script
    end

    def update
      @script = account.scripts.find(params[:id])
      save_script
    end

    def destroy
      @script = account.scripts.find(params[:id])
      @script.active = false
      @script.save ? flash_message(:notice, "Script deleted") : flash_message(:error, @script.errors.full_messages.join)
      respond_with @script, location: client_scripts_path
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

    def new_script
      @script = account.scripts.new(robo: false)
    end

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
      flash_message(:notice, "Script saved") if @script.update_attributes(params[:script])
      if params[:save_as]
        @new_script = @script.clone
        new_script.script_texts << @script.script_texts.collect {|script_text| script_text.clone}
        new_script.notes << @script.notes.collect {|note| note.clone}
        new_script.questions << @script.questions.collect do |question|
          new_question = question.clone
          new_question.possible_responses << question.possible_responses.collect {|possible_response| possible_response.clone}
        end
        @new_script.name = ''
        @script = @new_script
        render 'new'
      else
        respond_with @script, location: client_scripts_path
      end
    end
  end
end
