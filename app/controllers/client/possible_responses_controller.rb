module Client
  class PossibleResponsesController < ClientController
    before_filter :load_and_verify_script_and_question
    before_filter :load_possible_response, only: [:show, :destroy, :update]
    respond_to :json

    if instrument_actions?
      instrument_action :index, :create, :show, :update, :destroy
    end

    def index
      respond_with(@question.possible_responses)
    end

    def create
      possible_response = @question.possible_responses.new(possible_response_params)
      possible_response.save
      respond_with possible_response, location: client_script_question_possible_responses_path
    end

    def show
      respond_with(@possible_response)
    end

    def update
      @possible_response.update_attributes(possible_response_params)
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
        @script   = Script.includes(:questions).find(params[:script_id])
        @question = @script.questions.find(params[:question_id])
      rescue ActiveRecord::RecordNotFound => e
        render :json=> {"message"=>"Resource not found"}, :status => :not_found
        return
      end
      if @script.account != account
        render :json => {message: 'Cannot access script.'}, :status => :unauthorized
        return
      end
    end

    def possible_response_params
      params.require(:possible_response).permit(
        :question_id, :keypad, :value, :retry, :possible_response_order
      )
    end
  end
end
