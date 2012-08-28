module Client
  class NotesController < ClientController
    respond_to :json

    def index
      respond_with(account.notes)
    end

    def create
      respond_with(Note.create(params[:note]))
    end

    def show
      respond_with(Note.find(params[:id]))
    end

    def update
      respond_with(Note.find(params[:id]).update_attributes(params[:note]))
    end

    def destroy
      respond_with(Note.find(params[:id].destroy))
    end
  end
end
