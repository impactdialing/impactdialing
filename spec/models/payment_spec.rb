require 'spec_helper'

describe Payment do

  it "creates new users in trial with a 9 dollar balance" do
    user = Factory(:user)
    user.create_promo_balance
    user.account.current_balance.should == 9.0
    user.account.active_subscription.should=="Per Minute"
  end

  it "debits the balance for per minute calls" do
    user = Factory(:user)
    account = Factory(:account)
    user.update_attribute(:account, account)
    user.create_promo_balance
    account.active_subscription.should=="Per Minute"

    ##### TRIAL #####
    user.account.current_balance.should == 9.0
    campaign = Factory(:campaign, :robo => false, :account => account)

    caller_session = Factory( :caller_session, :campaign => campaign, :starttime => Time.now, :endtime => (Time.now + 150.seconds))
    call_attempt = Factory(:call_attempt, :campaign => campaign,  :voter => Factory(:voter, :status => Voter::Status::NOTCALLED), :caller_session => caller_session, :campaign => campaign)
    user.account.current_balance.should == 9.0

    ##### CALL_ATTEMPT (9c) #####
    
    call_attempt = Factory(:call_attempt, :call_start => Time.now, :call_end => (Time.now + 150.seconds), :campaign=>campaign)
    payment = call_attempt.debit
    payment.class.should == Payment
    user.account.current_balance.should == 8.73

    ##### ROBO CALL_ATTEMPT (4c) #####
    
    campaign.robo=true
    call_attempt2 = Factory(:call_attempt, :call_start => Time.now, :call_end => (Time.now + 150.seconds), :campaign=>campaign)
    payment = call_attempt2.debit
    payment.class.should == Payment
    user.account.current_balance.should == 8.61

    ##### CALLER_SESSION (9c) #####
    caller_session.debit
    user.account.current_balance.should == 8.34

  end


  it "debits the balance for calls on per caller plan" do
    user = Factory(:user)
    account = Factory(:account,:subscription_name=>"Per Caller", :subscription_active=>true)
    user.update_attribute(:account, account)
    user.create_promo_balance
    account.active_subscription.should=="Per Caller"

    user.account.current_balance.should == 9.0
    campaign = Factory(:campaign, :robo => false, :account => account)

    caller_session = Factory( :caller_session, :campaign => campaign, :starttime => Time.now, :endtime => (Time.now + 150.seconds))
    call_attempt = Factory(:call_attempt, :campaign => campaign,  :voter => Factory(:voter, :status => Voter::Status::NOTCALLED), :caller_session => caller_session, :campaign => campaign)
    user.account.current_balance.should == 9.0

    ##### CALL_ATTEMPT (2c) #####
    
    call_attempt = Factory(:call_attempt, :call_start => Time.now, :call_end => (Time.now + 150.seconds), :campaign=>campaign)
    payment = call_attempt.debit
    payment.class.should == Payment
    user.account.current_balance.should == 8.94

    ##### ROBO CALL_ATTEMPT (2c) #####
    
    campaign.robo=true
    call_attempt2 = Factory(:call_attempt, :call_start => Time.now, :call_end => (Time.now + 150.seconds), :campaign=>campaign)
    payment = call_attempt2.debit
    payment.class.should == Payment
    user.account.current_balance.should == 8.88

    ##### CALLER_SESSION (2c) #####
    caller_session.debit
    user.account.current_balance.should == 8.82

  end



end
