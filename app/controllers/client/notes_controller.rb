module Client
  class NotesController < ClientController
    before_filter :load_and_verify_script
    before_filter :load_note, only: [:show, :destroy, :update]
    respond_to :json

    def index
      respond_with(@script.notes)
    end

    def create
      note = @script.notes.new(params[:note])
      note.save
      respond_with note,  location: client_script_notes_path      
    end

    def show
      respond_with(@note)
    end

    def update
      @note.update_attributes(params[:note])
      respond_with @note,  location: client_script_note_path do |format|         
        format.json { render :json => {message: "Note updated" }, :status => :ok } if @note.errors.empty?
      end            
    end

    def destroy
      @note.destroy
      render :json => { message: 'Note Deleted', status: :ok}
    end
  
  private
  
  def load_note
    begin
      @note = @script.notes.find(params[:id])
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
