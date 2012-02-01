class MessagesController < ClientController
  layout 'v2'
  def new
    @script = Script.new
    @script.robo_recordings.build
  end

  def create
    @script = Script.create(params[:script].merge(:robo => true, :for_voicemail => true))
    redirect_to message_path(@script)
  end

  def show
    @script = Script.find(params[:id])
  end
end
