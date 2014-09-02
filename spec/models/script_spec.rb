require "spec_helper"

describe Script, :type => :model do

  describe 'after_update' do
    include FakeCallData

    it 'queues job to update redis cache (job will only alter cache if data already cached and does not match fresh data)' do
      admin   = create(:user)
      account = admin.account
      script  = create_campaign_with_script(:bare_power, account).first

      expect(CachePhonesOnlyScriptQuestions).to receive(:add_to_queue).with(script.id, 'update')

      script.update_attributes(name: 'Updated Script Name')
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
    expect(Script.by_updated.all).to eq([newer_script, older_script])
  end

  it "lists active scripts" do
    inactive = create(:script, :active => false)
    active = create(:script, :active => true)
    expect(Script.active).to include(active)
  end

  describe "questions and responses" do
    it "gets all questions and responses" do
      script = create(:script)
      question = create(:question, :script => script)
      response_1 = create(:possible_response, :question => question)
      another_response = create(:possible_response)
      expect(script.questions_and_responses).to eq({question.text => [question.possible_responses.first.value, response_1.value]})
    end
  end

  describe "deletion" do
    it "should not delete a script that is being used by a campaign" do
      script = create(:script)
      campaign = create(:campaign, script: script)
      script.active = false
      expect(script.save).to be_falsey
      expect(script.errors[:base]).to eq([I18n.t(:script_cannot_be_deleted)])
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
