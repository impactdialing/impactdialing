require "spec_helper"

describe Enterprise do
    describe "campaign_types" do
    it "should return preview and power modes" do
     Enterprise.new.campaign_types.should eq([Campaign::Type::PREVIEW, Campaign::Type::POWER, Campaign::Type::PREDICTIVE])
    end
  end

  describe "campaign_type_options" do
    it "should return preview and power modes" do
     Enterprise.new.campaign_type_options.should eq([[Campaign::Type::PREVIEW, Campaign::Type::PREVIEW], [Campaign::Type::POWER, Campaign::Type::POWER],[Campaign::Type::PREDICTIVE, Campaign::Type::PREDICTIVE]])
    end
  end
  describe "campaign" do
    before(:each) do
      @account =  create(:account, record_calls: false)
      Enterprise.create!(account_id: @account.id, number_of_callers: 1, status: Subscription::Status::UPGRADED)
    end

    it "should  allow predictive dialing mode for enterprise subscription" do
      campaign = build(:predictive, account: @account)
      campaign.save.should be_true
    end

    it "should not allow preview dialing mode for enterprise subscription" do
      campaign = build(:preview, account: @account)
      campaign.save.should be_true
    end

    it "should not allow power dialing mode for enterprise subscription" do
      campaign = build(:power, account: @account)
      campaign.save.should be_true
    end
  end

  describe "transfer_types" do
    it "should return warm and cold transfers" do
      Enterprise.new.transfer_types.should eq([Transfer::Type::WARM, Transfer::Type::COLD])
    end
  end

  describe "transfers" do
    before(:each) do
      @account =  create(:account, record_calls: false)
      Enterprise.create!(account_id: @account.id, number_of_callers: 1, status: Subscription::Status::UPGRADED)
    end

    it "should not all saving transfers" do
      script = build(:script, account: @account)
      script.transfers << build(:transfer)
      script.save
      script.errors[:base].should == ["Your subscription does not allow transfering calls in this mode."]
    end
  end

  describe "caller groups" do
    describe "caller_groups_enabled?" do
      it "should say enabled" do
        Enterprise.new.caller_groups_enabled?.should be_true
      end
    end

    describe "it should  allow caller groups for callers" do
      before(:each) do
        @account =  create(:account, record_calls: false)
        Enterprise.create!(account_id: @account.id, number_of_callers: 1, status: Subscription::Status::UPGRADED)
      end

      it "should save caller with caller groups" do
        caller = build(:caller, account: @account)
        caller.caller_group = build(:caller_group)
        caller.save.should be_true
      end
    end
  end

  describe "call recordings" do
    describe "call_recording_enabled?" do
      it "should say  enabled" do
        Enterprise.new.call_recording_enabled?.should be_true
      end
    end

    describe "it should allow call recordings to be enabled" do
      before(:each) do
        @account =  create(:account, record_calls: false)
        Enterprise.create!(account_id: @account.id, number_of_callers: 1, status: Subscription::Status::UPGRADED)
      end

      it "should all record calls" do
        @account.update_attributes(record_calls: true).should be_true
      end
    end
  end

  describe ".upgrade(account)" do
    let(:account){ create(:account) }
    let(:trial) do
      create(:trial, {
        account: account,
        number_of_callers: 1
      })
    end

    describe 'update last subscription' do
      it 'zeros minutes on all subscriptions' do
        account.should_receive(:zero_all_subscription_minutes!){ true }
        Enterprise.upgrade(account)
      end

      it 'raises Enterprise::UpgradeError exception when it fails to zero minutes' do
        account.stub(:zero_all_subscription_minutes!){ trial }
        lambda{ Enterprise.upgrade(account) }.should raise_error(Enterprise::UpgradeError)
      end
    end

    describe 'create a new Enterprise subscription obj' do
      let(:enterprise) do
        double(:enterprise, {
          save: true,
          errors: double(:errors, {
            full_messages: []
          })
        })
      end
      it 'instantiates the obj passing the account and status: Upgraded' do
        Enterprise.should_receive(:new).with({
          account_id: account.id,
          status: Subscription::Status::UPGRADED,
          subscription_start_date: anything,
          subscription_end_date: anything
        }){ enterprise }
        Enterprise.upgrade(account)
      end
      it 'raises Enterprise::UpgradeError when obj save fails' do
        enterprise.stub(:save){ false }
        Enterprise.stub(:new){ enterprise }
        lambda{ Enterprise.upgrade(account) }.should raise_error(Enterprise::UpgradeError)
      end
      it 'sends account a msg: :upgraded_to_enterprise' do
        Enterprise.stub(:new){ enterprise }
        account.should_receive(:upgraded_to_enterprise)
        Enterprise.upgrade(account)
      end
    end
  end

  describe '#debit(call_time)' do
    context 'for pre-pay plans' do
      let(:enterprise) do
        create(:enterprise, {
          total_allowed_minutes: 5000,
          minutes_utlized: 0
        })
      end

      it 'increments :minutes_utlized by call_time' do
        enterprise.debit(582)
        enterprise.reload
        enterprise.minutes_utlized.should eq 582
      end
    end

    context 'for manually invoiced plans' do
      let(:enterprise){ create(:enterprise) }

      it 'returns true' do
        enterprise.debit(234).should be_true
        enterprise.minutes_utlized.should eq 0
      end
    end
  end
end
