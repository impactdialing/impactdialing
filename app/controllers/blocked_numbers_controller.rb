class BlockedNumbersController < ClientController
private
  def level_for_flash(blocked_number)
    if blocked_number.campaign_id.nil?
      'System'
    else
      blocked_number.campaign.name
    end
  end

public
  def index
    @blocked_numbers = account.blocked_numbers.includes(:campaign).paginate :page => params[:page], :order => 'id'
    @campaigns = account.campaigns.active
  end

  def create
    @blocked_number = account.blocked_numbers.create(params[:blocked_number])
    unless @blocked_number.valid?
      @blocked_number.errors.full_messages.each do |message|
        flash_message(:error, message)
      end
    else
      level = level_for_flash(@blocked_number)
      flash_message(:notice, I18n.t(:blocked_number_created, number: @blocked_number.number, level: level))
    end
    redirect_to :back
  end

  def destroy
    blocked_number = account.blocked_numbers.find(params[:id])
    level          = level_for_flash(blocked_number)
    blocked_number.destroy
    flash_message(:notice, I18n.t(:blocked_number_deleted, number: blocked_number.number, level: level))
    redirect_to :back
  end
end
