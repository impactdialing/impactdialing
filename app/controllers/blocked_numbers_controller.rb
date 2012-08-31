class BlockedNumbersController < ClientController
  def index
    @blocked_numbers = account.blocked_numbers.paginate :page => params[:page], :order => 'id'
    @campaigns = account.campaigns.active
  end

  def create
    @blocked_number = account.blocked_numbers.create(params[:blocked_number])
    unless @blocked_number.valid?
      @blocked_number.errors.full_messages.each do |message|
        flash_message(:error, message)
      end
    else
      flash_message(:notice, "Do Not Call number added")
    end
    redirect_to :back
  end

  def destroy
    account.blocked_numbers.find(params[:id]).destroy
    redirect_to :back
  end
end
