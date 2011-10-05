class BlockedNumbersController < ClientController
  def index
    @blocked_numbers = current_user.blocked_numbers
  end
  
  def create
    @blocked_number = current_user.blocked_numbers.create(:number => params[:blocked_number][:number])
    unless @blocked_number.valid?
      @blocked_number.errors.full_messages.each do |message|
        flash_message(:error, message)
      end
    else
      flash_message(:notice, "Do not call number added.")
    end
    redirect_to :back
  end
end