class RecurlyController < ApplicationController
  protect_from_forgery :except => :notification
  
  def notification
    #recurly push notification http://docs.recurly.com/api/push-notifications
    doc = Nokogiri::XML(request.body)
    notification_type = doc.root.name
    account_code = doc.xpath("//account_code").first.text
    @account = Account.where("recurly_account_code=?", account_code).first
    raise "received a recurly notification for account #{account_code} but no local account matches" if @account.nil?
    if notification_type=="expired_subscription_notification" || notification_type=="reactivated_account_notification"
      @account.sync_subscription
    else
      # ignoring these types for now
      # new_account_notification
      # billing_info_updated_notification
      # new_subscription_notification
      # updated_subscription_notification
      # renewed_subscription_notification
      # successful_payment_notification
      # failed_payment_notification
      # successful_refund_notification
      # void_payment_notification
      # canceled_account_notification
      # canceled_subscription_notification
    end
    
    render :text=>"ok"
  end
  
end
