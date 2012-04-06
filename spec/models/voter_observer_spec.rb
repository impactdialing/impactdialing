require "spec_helper"

describe VoterObserver do
  let(:script) { Factory(:script) }
  let(:campaign) { Factory(:campaign, :script => script) }
  let(:voter) { Factory(:voter, :campaign => campaign) }

  describe "answers" do
    let(:caller_session) { Factory(:caller_session, :campaign => campaign, :session_key => "key") }
    let(:call_attempt) { Factory(:call_attempt, :caller_session => caller_session, :voter => voter)}
    let(:question) { Factory(:question, :script => script) }
    let(:response) { Factory(:possible_response, :question => question, :keypad => 1, :value => "response")}


    before(:each) do
      voter.update_attribute(:last_call_attempt, call_attempt)
    end

    it "pushes next voter after an answer is recorded" do
      pending
      event, data = 'voter_push', {}
      channel = mock
      Pusher.should_receive(:[]).with(caller_session.session_key).and_return(channel)
      channel.should_receive(:trigger_async).with(event, data.merge(:dialer => campaign.predictive_type))

      voter.answer(question,"1")
    end

  end

end
