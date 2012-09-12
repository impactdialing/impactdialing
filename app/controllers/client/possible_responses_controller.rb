module Client
  class PossibleResponsesController < ClientController
    before_filter :load_and_verify_script_and_question
    before_filter :load_possible_response, only: [:show, :destroy, :update]
    respond_to :json


    def index
      respond_with(@question.possible_responses)
    end

    def create
      possible_response = @question.possible_responses.new(params[:possible_response])
      possible_response.save
      respond_with possible_response,  location: client_script_question_possible_responses_path            
    end

    def show
      respond_with(@possible_response)
    end

    def update
      @possible_response.update_attributes(params[:possible_response])
      respond_with @possible_response,  location: client_script_question_possible_responses_path do |format|         
        format.json { render :json => {message: "Possible Response updated" }, :status => :ok } if @possible_response.errors.empty?
      end            
    end

    def destroy
      @possible_response.destroy
      render :json => { message: 'Possible Response Deleted', status: :ok}
    end
    
    private
    def load_possible_response
      begin
        @possible_response = @question.possible_responses.find(params[:id])
      rescue ActiveRecord::RecordNotFound => e
        render :json=> {"message"=>"Resource not found"}, :status => :not_found
        return
      end
    end


    def load_and_verify_script_and_question
      begin
        @script = Script.find(params[:script_id])
        @question = Question.find(params[:question_id])
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
