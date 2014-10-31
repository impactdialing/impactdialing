require 'spec_helper'

describe UserMailer, :type => :mailer do
  include ExceptionMethods

  let(:white_labeled_email){ 'info@stonesphones.com' }
  let(:white_label){ 'stonesphonesdialer' }

  before(:each) do
    @mandrill = double
    @mailer = UserMailer.new
    allow(@mailer).to receive(:email_domain).and_return({'email_addresses'=>['email@impactdialing.com', white_labeled_email]})
  end

  it 'delivers confirmation for uploaded voter list' do
    VCR.use_cassette('email confirmation for voter list upload') do
      domain = 'dc-London'
      expect(@mailer).to receive(:send_email).with(anything)
      @mailer.voter_list_upload({'success' => ['true']}, domain, 'test@email.com', 'test')
    end
  end

  it 'defaults from_email to email@impactdialing.com when unverified' do
    VCR.use_cassette('email unverified something or other') do
      expect(@mailer.white_labeled_email('unverified@email.com')).to eq('email@impactdialing.com')
    end
  end

  it 'uses white labeled email when verified' do
    #WhiteLabeling.stub(:white_labeled_email).and_return(white_labeled_email)
    mandrill = double
    expect(Mandrill::API).to receive(:new).and_return(mandrill)
    expect(mandrill).to receive(:call).with('senders/domains').and_return([{'domain'=> 'stonesphonesdialer'}])
    expect(UserMailer.new.white_labeled_email(white_label)).to eq(white_labeled_email)
  end

  describe 'end-user notifications' do
    let :user do
      double({
        domain: 'test.com',
        email: 'user@test.com'
      })
    end
    let :campaign do
      double({
        name: 'Teste'
      })
    end
    let(:account_id) { 111 }
    after do
      VCR.use_cassette('email download fail message') do
        @mailer.deliver_download_failure(user, campaign)
      end
    end

    describe '#deliver_download_failure(user, campaign)' do
      it 'has a subject of :report_error_occured_subject' do
        expect(@mailer).to receive(:send_email).with({
          to: anything,
          subject: I18n.t(:report_error_occured_subject),
          html: anything,
          text: anything,
          from_name: anything,
          from_email: anything
        })
      end

      it 'is sent to the user' do
        expect(@mailer).to receive(:send_email).with({
          to: [{ email: user.email }],
          subject: anything,
          html: anything,
          text: anything,
          from_name: anything,
          from_email: anything
        })
      end

      it 'with content from :report_error_occured' do
        content = "<br/>#{I18n.t(:report_error_occured)}"

        expect(@mailer).to receive(:send_email).with({
          to: anything,
          subject: anything,
          html: content,
          text: content,
          from_name: anything,
          from_email: anything
        })
      end
    end
  end

  describe '#deliver_exception_notification(msg, exception)' do
    let(:content) { 'Some context-sensitive notes that appear above the backtrace...' }
    let(:exception) { fake_exception }

    after do
      @mailer.deliver_exception_notification(content, exception)
    end

    it 'sends deliver_exception_notification exception messages to EXCEPTIONS_EMAIL' do
      expect(@mailer).to receive(:send_email).with({
        to: [{email: EXCEPTIONS_EMAIL}],
        subject: anything,
        html: anything,
        text: anything,
        from_name: anything,
        from_email: anything
      })
    end

    it 'has a subject with the exception message' do
      expect(@mailer).to receive(:send_email).with({
        to: anything,
        subject: exception.message,
        html: anything,
        text: anything,
        from_name: anything,
        from_email: anything
      })
    end
  end
end
