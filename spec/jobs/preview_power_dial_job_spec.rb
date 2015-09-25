require 'rails_helper'

describe PreviewPowerDialJob do  
  let(:account){ create(:account) }
  let(:caller_record){ create(:caller, account: account) }
  let(:caller_session){ create(:caller_session, caller: caller_record, campaign: caller_record.campaign) }
  let(:phone){ Forgery(:address).clean_phone }
  let(:call_storage) do
    instance_double('CallFlow::Call::Storage')
  end
  let(:dialed_call) do
    instance_double('CallFlow::Call::Dialed', {
      storage: call_storage
    })
  end

  before do
    expect(CallerSession).to receive_message_chain(:includes, :find_by_id).and_return(caller_session)
  end

  subject{ PreviewPowerDialJob.new }

  it "dials a phone number" do
    expect(Twillio).to receive(:dial).with(phone, caller_session)
    subject.perform(caller_session.id, phone)
  end

  it 'does not dial a number that was already dialed' do
    allow(call_storage).to receive(:[]).with(:phone){ phone }
    allow(caller_session).to receive(:dialed_call){ dialed_call }
    expect(Twillio).to_not receive(:dial)
    subject.perform(caller_session.id, phone)
  end
end

