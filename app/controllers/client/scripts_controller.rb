module Client
  class ScriptsController < ::ScriptsController
    skip_before_filter :load_script, :apply_changes, :question_answered

    layout 'client'

    def deleted
      render 'scripts/deleted'
    end

    def index
      @scripts = @user.scripts.manual.active.paginate(:page => params[:page])
    end

    def new
      @script = Script.new(:robo => false, questions: [Question.new(possible_responses: [PossibleResponse.new])])
      @voter_fields = VoterList::VOTER_DATA_COLUMNS.values
      @voter_fields.concat(@user.account.custom_voter_fields.collect{ |field| field.name})
      @voter_field_values=[]
    end

    def create
      params[:script][:voter_fields] =  params[:voter_field] ? params[:voter_field].to_json : nil
      @script = Script.new(params[:script])
      @voter_fields = Voter.upload_fields
      @voter_field_values = params[:voter_field] || []
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
      @voter_fields = VoterList::VOTER_DATA_COLUMNS.values
      @voter_fields.concat(@user.account.custom_voter_fields.collect{ |field| field.name})
      @answered_questions = Question.question_count_script(@script.id).to_json
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
    

    def update
      @script = @user.account.scripts.find(params[:id])
      params[:script][:voter_fields] =  params[:voter_field] ? params[:voter_field].to_json : nil
      @voter_fields = VoterList::VOTER_DATA_COLUMNS.values
      @voter_fields.concat(@user.account.custom_voter_fields.collect{ |field| field.name})
      @voter_field_values = (JSON.parse(@script.voter_fields) if @script.voter_fields) || []
      @answered_questions = Question.question_count_script(@script.id)
      puts params[:script]
      begin
        params[:save_as] ? save_as : @script = account.scripts.find_by_id(params[:id])
        puts params[:script]
        if params[:save_as]
          redirect_to client_script_path(@script)          
        elsif !params[:save_as] &&  @script.update_attributes(params[:script])
          flash_message(:notice, "Script updated")
          redirect_to :action=>"index"
        else
          render :show
        end
      rescue Exception => e
        puts e.backtrace
        flash_message(:notice, "Script not saved. Error:" + e.message)
        render :show
      end
    end

    def destroy
      @script = @user.account.scripts.manual.find(params[:id])
      unless @script.nil?
        campaign = @user.account.campaigns.active.find_by_script_id(@script.id)
        if campaign.nil?
          @script.update_attributes(:active => false)
          flash_message(:notice, "Script deleted")
        else
          flash_message(:notice, I18n.t(:script_cannot_be_deleted))
        end
      end
      redirect_to :action => "index"
    end
    
    def question_answered
      question = Question.find(params[:question_id])
      render :json => { :data => question.answered? }
    end
    
    def load_deleted
      self.instance_variable_set("@#{type_name.pluralize}", Script.deleted.for_account(@user.account).paginate(:page => params[:page], :order => 'id desc'))
    end    
    

    private

    def save_as
      @script = Script.new(:name => "", :active => true, :account => @user.account, :script => params[:script][:script], :voter_fields => params[:script][:voter_fields])
      @script.save(:validate => false)
      params[:script][:questions_attributes].each_value.each do |q|
        if q[:_destroy] == "false"
          question = @script.questions.new(:text => q[:text])
          question.save!
          q[:possible_responses_attributes].each_value.each do |ps|
            if ps[:_destroy] == "false"
              possible_response = question.possible_responses.new(:value => ps[:value], :keypad => ps[:keypad], :retry => ps[:retry])
              possible_response.save!
            end
          end
        end
      end
      params[:script][:notes_attributes].try(:each_value).try(:each) do |n|
        if n[:_destroy] == "false"
          note = @script.notes.new(:note => n[:note])
          note.save!
        end
      end
    end

  end
end
