class MessagesController < ClientController

  def new
    @script = Script.new
    @script.robo_recordings.build
  end

  def create
    @script = Script.new(params[:script].merge(:robo => true, :for_voicemail => true, :active => true, :account => account))
    if @script.save
      redirect_to scripts_path
    else
      render :action => 'new'
    end
  end

  def show
    @script = Script.find(params[:id])
  end

  def update
    @script = Script.find(params[:id])
    @script.update_attributes(params[:script])
    redirect_to scripts_path
  end
end
