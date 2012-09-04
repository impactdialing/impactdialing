module Client
  class QuestionsController < ClientController
    respond_to :json

    def index
      respond_with(account.questions)
    end

    def create
      respond_with(account.questions.create(params[:question]))
    end

    def show
      respond_with(account.questions.find(params[:id]))
    end

    def update
      respond_with(account.questions.find(params[:id]).update_attributes(params[:question]))
    end

    def destroy
      respond_with(account.questions.find(params[:id]).destroy)
    end
  end
end
