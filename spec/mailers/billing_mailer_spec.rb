require "spec_helper"

describe BillingMailer, :type => :mailer do
  let(:account){ create(:account) }
  let(:invoice_recipient){ 'blah@test.com' }
  subject{ BillingMailer.new(account) }

  before do
    allow(subject).to receive(:invoice_recipient){ invoice_recipient }
    WebMock.disable_net_connect!
  end

  describe '#autorecharge_failed' do
    before do
      expect(subject).to receive(:send_email).with({
        :subject => "Autorecharge payment failed",
        :text => anything,
        :from_name => 'Impact Dialing',
        :from_email => FROM_EMAIL,
        :to=>[{email: invoice_recipient}],
        :track_opens => true,
        :track_clicks => true
      })
    end

    it 'renders and sends the email' do
      subject.autorecharge_failed
    end
  end

  describe '#autorenewal_failed' do
    before do
      expect(subject).to receive(:send_email).with({
        :subject => "Subscription renewal failed",
        :text => anything,
        :from_name => 'Impact Dialing',
        :from_email => FROM_EMAIL,
        :to=>[{email: invoice_recipient}],
        :track_opens => true,
        :track_clicks => true
      })
    end

    it 'renders and sends the email' do
      subject.autorenewal_failed
    end
  end
end
