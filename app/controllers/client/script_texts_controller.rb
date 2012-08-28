module Client
  class ScriptTextsController < ClientController
    respond_to :json

    def index
      respond_with(account.script_texts)
    end

    def create
      respond_with(ScriptText.create(params[:script_text]))
    end

    def show
      respond_with(ScriptText.find(params[:id]))
    end

    def update
      respond_with(ScriptText.find(params[:id]).update_attriubtes(params[:script_text]))
    end

    def destroy
      respond_with(ScriptText.find(params[:id].destroy))
    end
  end
end
