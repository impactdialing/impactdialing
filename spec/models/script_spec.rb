require 'rails_helper'

describe Script, :type => :model do

  describe 'after_update' do
    include FakeCallData

    let(:admin){ create(:user) }
    let(:account){ admin.account }
    let(:script){ create_campaign_with_script(:bare_power, account).first }

    context 'when script is active' do
      it 'queues job to update redis cache (job will only alter cache if data already cached and does not match fresh data)' do
        expect(CachePhonesOnlyScriptQuestions).to receive(:add_to_queue).with(script.id, 'update')

        script.update_attributes(name: 'Updated Script Name')
      end

      it 'queues job to cache Script#voter_fields' do
        script.update_attributes(name: 'Updated')
        actual = Resque.peek :dial_queue, 0, 100
        expect(actual).to include({
          'class' => 'CallFlow::Web::Jobs::CacheContactFields',
          'args' => [script.id]
        })
      end
    end

    context 'when script is not active' do
      it 'queues job to delete redis question cache' do
        script.campaigns.update_all(active: false)
        script.update_attributes!(active: false)
        expect([:resque, :dial_queue]).to have_queued(CachePhonesOnlyScriptQuestions).with(script.id, 'update')
      end
    end

    it 'publishes save notification via ActiveSupport::Notifications' do
      actual_payload = nil
      ActiveSupport::Notifications.subscribe('scripts.saved') do |name, start, finish, id, payload|
        actual_payload = payload
      end

      script.update_attributes(name: "Updated")
      expect(actual_payload[:script]).to eq script

      new_script = create(:script)
      expect(actual_payload[:script]).to eq new_script
    end
  end

  it 'returns transfer_types according to Ability' do
    user    = create(:user)
    account = user.account
    script  = create(:script, {account: account})

    expect(script.transfer_types).to eq [Transfer::Type::WARM, Transfer::Type::COLD]

    account.billing_subscription.update_attribute(:plan, 'basic')
    script2 = Script.last
    expect(script.id).to eq script2.id
    expect(script2.transfer_types).to eq []
  end

  it "restoring makes it active" do
    script = create(:script, :active => false)
    script.restore
    expect(script.active?).to eq(true)
  end

  xit "sorts by the updated date" do
    Script.record_timestamps = false
    older_script = create(:script).tap{|c| c.update_attribute(:updated_at, 2.days.ago)}
    newer_script = create(:script).tap{|c| c.update_attribute(:updated_at, 1.day.ago)}
    Script.record_timestamps = true
    expect(Script.by_updated.to_a).to eq([newer_script, older_script])
  end

  it "lists active scripts" do
    inactive = create(:script, :active => false)
    active = create(:script, :active => true)
    expect(Script.active).to include(active)
  end

  describe "Possible response uniqueness" do
    let(:possible_responses) do
      [
        build(:possible_response, {:keypad => 1, :question_id => nil}),
        build(:possible_response, {:keypad => 1, :question_id => nil})
      ]
    end
    let(:question) do
      build(:question, :script_id => nil, :possible_responses => possible_responses)
    end
    let(:script) do
      build(:script, {:questions => [question]})
    end

    it "displays an error message if a more than one of a question's possible phone-only responses use the same key" do
      expect(script.save).to eq(false)
    end

    it "bypasses uniqueness check on keys if they are all nil" do
      possible_responses.each { |pr| pr.keypad=nil }
      expect(script.save).to eq(true)
    end

    it "checks uniqueness of keypad responses on script update" do
      possible_responses.last.keypad = 2
      script.save
      script.update_attributes({
        questions_attributes: [
          question.attributes.merge({
            possible_responses_attributes: [
              possible_responses.first.attributes.merge({
                :keypad => 2
              }),
              possible_responses.last.attributes
            ]
          })
        ]
      })
      expect(script.errors.full_messages.join).to eq("Questions \"#{question.text}\" has duplicate keypad values")
    end
  end

  describe "deletion" do
    it "should not delete a script that is being used by a campaign" do
      script = create(:script)
      campaign = create(:campaign, script: script)
      script.active = false
      expect(script.save).to be_falsey
      expect(script.errors[:base]).to eq([I18n.t(:script_cannot_be_archived)])
    end

    it "should delete a script that is not used by any campaign" do
      script = create(:script)
      campaign = create(:campaign)
      script.active = false
      expect(script.save).to be_truthy
    end
  end
end

# ## Schema Information
#
# Table name: `scripts`
#
# ### Columns
#
# Name                | Type               | Attributes
# ------------------- | ------------------ | ---------------------------
# **`id`**            | `integer`          | `not null, primary key`
# **`name`**          | `string(255)`      |
# **`active`**        | `boolean`          | `default(TRUE)`
# **`account_id`**    | `integer`          |
# **`created_at`**    | `datetime`         |
# **`updated_at`**    | `datetime`         |
# **`voter_fields`**  | `text(2147483647)`  |
#
