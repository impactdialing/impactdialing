class BlockedNumbersController < ClientController
  def index
    @blocked_numbers = current_user.blocked_numbers
    @campaigns = current_user.campaigns.active
  end
  
  def create
    @blocked_number = current_user.blocked_numbers.create(params[:blocked_number])
    unless @blocked_number.valid?
      @blocked_number.errors.full_messages.each do |message|
        flash_message(:error, message)
      end
    else
      flash_message(:notice, "Do not call number added.")
    end
    redirect_to :back
  end

  def destroy
    current_user.blocked_numbers.find(params[:id]).destroy
    redirect_to :back
  end
end