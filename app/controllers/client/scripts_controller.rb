module Client
  class ScriptsController < ClientController
    before_filter :load_and_verify_script, :except => [:index, :new, :create, :archived]
    before_filter :load_voter_fields, :only => [ :show, :edit]
    before_filter :check_admin_only

    respond_to :html, :json

    if instrument_actions?
      instrument_action :archived, :restore, :questions_answered, :possible_responses_answered
    end

    def index
      @scripts = account.scripts.active.paginate(:page => params[:page])
      respond_with @scripts
    end

    def show
      respond_with @script do |format|
        format.html {redirect_to edit_client_script_path(@script)}
      end
    end

    def edit
      respond_with @script
    end

    def new
      if params[:script_id]
        load_and_verify_script
        @script = @script.deep_clone include: [:transfers, :notes, :script_texts, questions: :possible_responses], except: :name
        load_voter_fields
      else
        new_script
        load_voter_fields
        @script.script_texts.new(script_order: 1)
        @question = @script.questions.new(script_order: 2)
        # @question.possible_responses.new(value: "[No response]", possible_response_order: 1, keypad: 1)
      end
      respond_with @script
    end

    def create
      new_script
      save_script
      load_voter_fields
      respond_with @script, location: client_scripts_path
    end

    def edit
      respond_with @script
    end

    def update
      if params[:save_as]
        @script = @script.deep_clone include: [:transfers, :notes, :script_texts, questions: :possible_responses], except: :name
        load_voter_fields
        render 'new'
      else
        save_script
        load_voter_fields
        respond_with @script,  location: client_scripts_path do |format|
          format.json { render :json => {message: "Script updated" }, :status => :ok } if @script.errors.empty?
        end
      end
    end

    def destroy
      @script.active = false
      @script.save ?  flash_message(:notice, "Script archived") : flash_message(:error, @script.errors.full_messages.join)
      respond_with @script,  location: client_scripts_path do |format|
        format.json { render :json => {message: "Script archived" }, :status => :ok } if @script.errors.empty?
      end
    end

    def questions_answered
      render :json => { :data => Question.question_count_script(@script.id) }
    end

    def possible_responses_answered
      render :json => { :data => PossibleResponse.possible_response_count(params[:question_ids]) }
    end

    def archived
      @scripts = account.scripts.archived.paginate(:page => params[:page], :order => 'id desc')
      respond_with @scripts do |format|
        format.html{ render :archived }
        format.json{ render :json => @scripts.to_json }
      end
    end

    def restore
      @script.active = true
      if @script.save
        flash_message(:notice, 'Script restored')
      else
        flash_message(:error, @script.errors.full_messages.join('; '))
      end

      respond_with @script, location: client_scripts_path do |format|
        format.json { render :json => {message: "Script restored" }, :status => :ok } if @script.errors.empty?
      end
    end

  private
    def load_and_verify_script
      begin
        @script = Script
        if params[:action] =~ /(update|edit|new)/
          @script = @script.includes(:notes, :script_texts, questions: :possible_responses)
        end
        @script = @script.find(params[:id] || params[:script_id])
      rescue ActiveRecord::RecordNotFound => e
        render :json => {"message"=>"Resource not found"}, :status => :not_found
        return
      end
      if @script.account != account
        render :json => {message: 'Cannot access script.'}, :status => :unauthorized
        return
      end
    end

    def new_script
      @script = account.scripts.new
    end

    def load_voter_fields
      @voter_fields = VoterList::VOTER_DATA_COLUMNS.values
      @voter_fields.concat(@user.account.custom_voter_fields.collect{ |field| field.name})
      if @script.voter_fields != nil
        begin
          @voter_field_values = JSON.parse(@script.voter_fields)
        rescue
          @voter_field_values = []
        end
      else
        @voter_field_values = []
      end
    end

    def save_script
      unless params[:script].nil?
        params[:script][:voter_fields] =  params[:voter_field] ? params[:voter_field].to_json : nil
      end
      flash_message(:notice, "Script saved") if @script.update_attributes(script_params)
    end

    def script_params
      params.require(:script).permit(
        :name, :voter_fields,
        notes_attributes: [:id, :note, :script_id, :script_order, :_destroy],
        script_texts_attributes: [:id, :content, :script_id, :script_order, :_destroy],
        questions_attributes: [
          :id, :text, :script_id, :script_order, :_destroy,
          possible_responses_attributes: [:id, :possible_response_order, :value, :retry, :keypad, :question_id, :_destroy]
        ],
        transfers_attributes: [:id, :label, :phone_number, :transfer_type, :script_id, :_destroy]
      )
    end
  end
end
