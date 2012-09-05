module Client
  class QuestionsController < ClientController
    respond_to :json
    
    def index
      respond_with(account.questions)
    end

    def create
      respond_with(Question.create(params[:question]))
    end

    def show
      respond_with(Question.find(params[:id]))
    end

    def update
      respond_with(Question.find(params[:id]).update_attributes(params[:question]))
    end

    def destroy
      respond_with(Question.find(params[:id].destroy))
    end
    
  end
end
