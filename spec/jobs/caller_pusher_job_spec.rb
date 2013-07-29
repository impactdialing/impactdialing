require "spec_helper"

describe CallerPusherJob do
  it "should send event" do
    caller_session = create(:caller_session, caller: create(:caller))
    CallerSession.should_receive(:find).and_return(caller_session)
    caller_session.should_receive(:publish_voter_disconnected)
    job = CallerPusherJob.new
    job.perform(caller_session.id, "publish_voter_disconnected")
  end
end