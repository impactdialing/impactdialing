module Client
  class QuestionsController < ClientController
    before_filter :load_and_verify_script
    before_filter :load_question, only: [:show, :destroy, :update]
    respond_to :json
    
    
    def index
      respond_with(@script.questions)
    end

    def create
      question = @script.questions.new(params[:question])
      question.save
      respond_with question,  location: client_script_questions_path      
    end

    def show
      respond_with(@question)
    end

    def update
      @question.update_attributes(params[:question])
      respond_with @question,  location: client_script_questions_path do |format|         
        format.json { render :json => {message: "Question updated" }, :status => :ok } if @question.errors.empty?
      end            
    end

    def destroy
      @question.destroy
      render :json => { message: 'Question Deleted', status: :ok}
    end
    
    private
    def load_question
      begin
        @question = @script.questions.find(params[:id])
      rescue ActiveRecord::RecordNotFound => e
        render :json=> {"message"=>"Resource not found"}, :status => :not_found
        return
      end
    end


    def load_and_verify_script
      begin
        @script = Script.find(params[:script_id])
      rescue ActiveRecord::RecordNotFound => e
        render :json=> {"message"=>"Resource not found"}, :status => :not_found
        return
      end
      if @script.account != account
        render :json => {message: 'Cannot access script.'}, :status => :unauthorized
        return
      end
    end
  end
end
