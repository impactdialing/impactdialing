class MessagesController < ClientController
  layout 'v2'
  def new
    @script = Script.new
    @script.robo_recordings.build
  end

  def create
    @script = Script.new(params[:script].merge(:robo => true, :for_voicemail => true, :active => true, :account => account))
    render :action => 'new' unless @script.save
    redirect_to message_path(@script) if @script.save
  end

  def show
    @script = Script.find(params[:id])
  end
end
