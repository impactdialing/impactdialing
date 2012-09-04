module Client
  class PossibleResponsesController < ClientController
    respond_to :json

    def index
      respond_with(account.possible_responses)
    end

    def create
      respond_with(account.possible_responses.create(params[:possible_response]))
    end

    def show
      respond_with(account.possible_responses.find(params[:id]))
    end

    def update
      respond_with(account.possible_responses.find(params[:id]).update_attributes(params[:possible_response]))
    end

    def destroy
      respond_with(account.possible_responses.find(params[:id]).destroy)
    end
  end
end
