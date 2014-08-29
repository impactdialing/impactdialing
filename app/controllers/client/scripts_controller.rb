module Client
  class ScriptsController < ClientController
    before_filter :load_and_verify_script, :except => [:index, :new, :create, :deleted]
    before_filter :load_voter_fields, :only => [ :show, :edit]

    respond_to :html, :json

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
      new_script
      load_voter_fields
      @script.script_texts.new(script_order: 1)
      @question = @script.questions.new(script_order: 2)
      # @question.possible_responses.new(value: "[No response]", possible_response_order: 1, keypad: 1)
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
        @script = @script.dup include: [:transfers, :notes, :script_texts, questions: :possible_responses], except: :name
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
      @script.save ?  flash_message(:notice, "Script deleted") : flash_message(:error, @script.errors.full_messages.join)
      respond_with @script,  location: client_scripts_path do |format|
        format.json { render :json => {message: "Script deleted" }, :status => :ok } if @script.errors.empty?
      end
    end

    def questions_answered
      render :json => { :data => Question.question_count_script(@script.id) }
    end

    def possible_responses_answered
      render :json => { :data => PossibleResponse.possible_response_count(params[:question_ids]) }
    end

    def deleted
      @scripts = Script.deleted.for_account(account).paginate(:page => params[:page], :order => 'id desc')
      respond_with @scripts do |format|
        format.html{render 'scripts/deleted'}
        format.json {render :json => @scripts.to_json}
      end
    end

    def restore
      @script.active = true
      save_script
      respond_with @script,  location: client_scripts_path do |format|
        format.json { render :json => {message: "Script restored" }, :status => :ok } if @script.errors.empty?
      end
    end

    private

    def load_and_verify_script
      begin
        @script = Script.find(params[:id] || params[:script_id])
      rescue ActiveRecord::RecordNotFound => e
        render :json=> {"message"=>"Resource not found"}, :status => :not_found
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
      unless params[:script].nil?
        params[:script][:voter_fields] =  params[:voter_field] ? params[:voter_field].to_json : nil
      end
      flash_message(:notice, "Script saved") if @script.update_attributes(params[:script])
    end
  end
end
