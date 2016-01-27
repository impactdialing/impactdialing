require 'rails_helper'

describe Caller do
  include Rails.application.routes.url_helpers

  let(:account){ create(:account) }
  let(:campaign){ create(:preview, account: account) }
  let(:caller_group){ create(:caller_group, campaign: campaign) }

  subject{ build(:caller, caller_group: caller_group, account: account) }

  it {is_expected.to belong_to :caller_group}

  describe 'before create' do
    it 'creates a unique PIN'
  end

  describe 'before validation' do
    before do
      subject.valid?
    end
    it 'assigns itself to the campaign of its caller group' do
      expect(subject.campaign).to eq campaign
    end
  end

  describe 'before save' do
    before do
      subject.save!
    end

    context 'campaign_id_changed? => true' do
      describe "reassign caller campaign" do
        let(:other_campaign){ create(:campaign, account: account) }
        let(:caller_session){ create(:caller_session, caller: subject) }

        shared_examples_for 'any campaign reassignment' do
          context 'caller is making calls' do
            before do
              caller_session.update_attribute(:on_call, false)
            end
            it "does nothing when campaign_id changes" do
              subject.update_attribute(:campaign_id, other_campaign.id)

              expect(caller_session.reassign_campaign).to eq(CallerSession::ReassignCampaign::NO)
            end
          end

          context 'caller is making calls' do
            before do
              caller_session.update_attribute(:on_call, true)
            end
            it "should set on call caller session to reassigned yes" do
              subject.update_attribute(:campaign, other_campaign)
              expect(caller_session.reload.reassign_campaign).to eq(CallerSession::ReassignCampaign::YES)
            end

            it "should set on RedisReassignedCallerSession campaign id" do
              subject.update_attributes(campaign: other_campaign)
              expect(RedisReassignedCallerSession.campaign_id(caller_session.id)).to eq(other_campaign.id.to_s)
            end
          end
        end

        context 'phone only caller' do
          before do
            subject.is_phones_only = true
            subject.save!
          end
          it_behaves_like 'any campaign reassignment'
        end

        context 'web or phone caller' do
          it_behaves_like 'any campaign reassignment'
        end
      end
    end
    context 'campaign_id_changed? => false' do
      before do
        subject.save!
      end
      it 'does nothing' do
        subject.username = Forgery(:name).first_name
        expect(subject.caller_sessions).to_not receive(:on_call)
        subject.save
      end
    end
  end

  describe 'a valid instance' do
    describe 'caller group' do
      it 'is optional' do
        subject.caller_group = nil
        subject.campaign = campaign
        expect(subject).to be_valid
      end
    end

    context 'assigned callers' do
      shared_examples_for 'an assigned caller' do
        it 'self.account_id must match campaign.account_id' do
          subject.account_id = campaign.account_id + 1
          expect(subject).to have(1).error_on(:campaign)
        end
      end

      context 'phones only' do
        before do
          subject.is_phones_only = true
        end
        it_behaves_like 'an assigned caller'
        it "requires a name" do
          subject.name = ''
          expect(subject).to have(1).error_on(:name)
        end
      end

      context 'web or phone' do
        before do
          subject.is_phones_only = false
        end
        it_behaves_like 'an assigned caller'
        describe 'username' do
          it "is required" do
            subject.username = ''
            expect(subject).to have_at_least(1).error_on :username
          end

          it "cannot have spaces" do
            subject.username = 'john doe'
            expect(subject).to have_at_least(1).error_on :username
          end

          it 'must be unique' do
            subject.save!
            caller_2 = build(:caller, campaign: campaign, username: subject.username)
            caller_2.valid?
            expect(caller_2.errors[:username]).to eq ['in use by another caller, it may have been archived']
          end
        end
      end
    end

    context 'orphaned callers' do
      let(:caller){ build(:caller) }
      before do
        subject.campaign_id = nil
      end
      it 'does not validate campaign presence' do
        expect(subject).to be_valid
      end
      it 'require a unique username' do
        subject.save!
        caller_2 = build(:caller, username: subject.username, campaign_id: nil)
        expect(caller_2).to be_invalid
      end
    end
  end

  describe '#identity_name' do
    context 'phone only caller' do
      before do
        subject.is_phones_only = true
        subject.name = 'Happy John'
      end
      it 'returns #name' do
        expect(subject.identity_name).to eq subject.name
      end
    end

    context 'web or phone caller' do
      it 'returns #username' do
        expect(subject.identity_name).to eq subject.username
      end
    end
  end

  describe '#restore' do
    it "restoring makes it active" do
      subject.active = false
      subject.save
      subject.restore
      expect(subject.active?).to eq(true)
    end
  end

  # todo: move Deletable unit specs deletable_spec.rb
  describe '(Deletable)' do
    describe '.by_updated' do
      it "sorts by the updated date" do
        older_caller = create(:caller).tap { |c| c.update_attribute(:updated_at, 2.days.ago) }
        newer_caller = create(:caller).tap { |c| c.update_attribute(:updated_at, 1.day.ago) }
        expect(Caller.by_updated.to_a).to eq [newer_caller, older_caller]
      end
    end
    describe '.active' do
      it "lists active callers" do
        active_caller = create(:caller, :active => true)
        inactive_caller = create(:caller, :active => false)
        expect(Caller.active.to_a).to eq [active_caller]
      end
    end
  end


  describe "reports" do
    let(:caller){ subject.save && subject }
    let!(:from_time) { 5.minutes.ago }
    let!(:time_now) { Time.now }

    before(:each) do
      create(:caller_session, caller_type: "Phone", tStartTime: Time.now, tEndTime: Time.now + (30.minutes + 2.seconds), :tDuration => 30.minutes + 2.seconds, :caller => caller).tap { |ca| ca.update_attribute(:created_at, from_time) }
      create(:caller_session, tStartTime: Time.now, tEndTime: Time.now + (101.minutes + 57.seconds), :tDuration => 101.minutes + 57.seconds, :caller => caller).tap { |ca| ca.update_attribute(:created_at, from_time) }
      create(:call_attempt, connecttime: Time.now, tStartTime: Time.now, tEndTime: Time.now + (10.minutes + 10.seconds), wrapup_time: Time.now + (10.minutes + 40.seconds), :tDuration => 10.minutes + 10.seconds, :status => CallAttempt::Status::SUCCESS, :caller => caller).tap { |ca| ca.update_attribute(:created_at, from_time) }
      create(:call_attempt, connecttime: Time.now, tStartTime: Time.now, tEndTime: Time.now + (1.minutes), :tDuration => 1.minutes, :status => CallAttempt::Status::VOICEMAIL, :caller => caller).tap { |ca| ca.update_attribute(:created_at, from_time) }
      create(:call_attempt, connecttime: Time.now, tStartTime: Time.now, tEndTime: Time.now + (101.minutes + 57.seconds), wrapup_time: Time.now + (102.minutes + 57.seconds), :tDuration => 101.minutes + 57.seconds, :status => CallAttempt::Status::SUCCESS, :caller => caller).tap { |ca| ca.update_attribute(:created_at, from_time) }
      create(:call_attempt, connecttime: Time.now, tStartTime: Time.now, tEndTime: Time.now + (1.minutes), :tDuration => 1.minutes, :status => CallAttempt::Status::ABANDONED, :caller => caller).tap { |ca| ca.update_attribute(:created_at, from_time) }
    end

    describe "utilization" do
      it "lists time logged in" do
        expect(CallerSession.time_logged_in(caller, nil, from_time, time_now)).to eq(7919)
      end

      it "lists on call time" do
        expect(CallAttempt.time_on_call(caller, nil, from_time, time_now)).to eq(6727)
      end

      it "lists on wrapup time" do
        expect(CallAttempt.time_in_wrapup(caller, nil, from_time, time_now)).to eq(90)
      end


    end

    describe "billing" do
      it "lists caller time" do
        expect(CallerSession.caller_time(caller, nil, from_time, time_now)).to eq(31)
      end

      it "lists lead time" do
        expect(CallAttempt.lead_time(caller, nil, from_time, time_now)).to eq(113)
      end
    end

    describe "campaign" do
      it "gets stats for answered calls" do
        @voter =  create(:voter)
        @script = create(:script)
        @question = create(:question, :text => "what?", script: @script)
        response_1 = create(:possible_response, :value => "foo", question: @question, possible_response_order: 1)
        response_2 = create(:possible_response, :value => "bar", question: @question, possible_response_order: 2)
        campaign = create(:campaign, script: @script)
        3.times { create(:answer, :caller => caller, :voter => @voter, :question_id => @question.id, :possible_response => response_1, :campaign => campaign) }
        2.times { create(:answer, :caller => caller, :voter => @voter, :question_id => @question.id, :possible_response => response_2, :campaign => campaign) }
        create(:answer, :caller => caller, :voter => @voter, :question => @question, :possible_response => response_1, :campaign => create(:campaign))
        stats = subject.answered_call_stats(from_time, time_now+1.day, campaign)

        expect(stats).to eq({
          "what?" => [
            {
              :answer=>"[No response]",
              :number=>0,
              :percentage=>0
            },
            {
              :answer=>"foo",
              :number=>3,
              :percentage=>60
            },
            {
              :answer=>"bar",
              :number=>2,
              :percentage=>40
            }
          ]
        })
      end
    end
  end

end

# ## Schema Information
#
# Table name: `callers`
#
# ### Columns
#
# Name                   | Type               | Attributes
# ---------------------- | ------------------ | ---------------------------
# **`id`**               | `integer`          | `not null, primary key`
# **`name`**             | `string(255)`      |
# **`username`**         | `string(255)`      |
# **`pin`**              | `string(255)`      |
# **`account_id`**       | `integer`          |
# **`active`**           | `boolean`          | `default(TRUE)`
# **`created_at`**       | `datetime`         |
# **`updated_at`**       | `datetime`         |
# **`password`**         | `string(255)`      |
# **`is_phones_only`**   | `boolean`          | `default(FALSE)`
# **`campaign_id`**      | `integer`          |
# **`caller_group_id`**  | `integer`          |
#
