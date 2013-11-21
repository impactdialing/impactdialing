require 'spec_helper'

describe UserMailer do
  include ExceptionMethods

  let(:white_labeled_email){ 'info@stonesphones.com' }
  let(:white_label){ 'stonesphonesdialer' }

  before(:each) do
    WebMock.allow_net_connect!
    @mandrill = double
    @mailer = UserMailer.new
    @mailer.stub(:email_domain).and_return({'email_addresses'=>['email@impactdialing.com', white_labeled_email]})
  end

  it 'delivers confirmation for uploaded voter list' do
    domain = 'dc-London'
    @mailer.should_receive(:send_email).with(anything)
    @mailer.voter_list_upload({'success' => ['true']}, domain, 'test@email.com', 'test')

  end

  it 'defaults from_email to email@impactdialing.com when unverified' do
    @mailer.white_labeled_email('unverified@email.com').should == 'email@impactdialing.com'
  end

  it 'uses white labeled email when verified' do
    #WhiteLabeling.stub(:white_labeled_email).and_return(white_labeled_email)
    mandrill = double
    Mandrill::API.should_receive(:new).and_return(mandrill)
    mandrill.should_receive(:call).with('senders/domains').and_return([{'domain'=> 'stonesphonesdialer'}])
    UserMailer.new.white_labeled_email(white_label).should == white_labeled_email
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
      @mailer.deliver_download_failure(user, campaign)
    end

    describe '#deliver_download_failure(user, campaign)' do
      it 'has a subject of :report_error_occured_subject' do
        @mailer.should_receive(:send_email).with({
          to: anything,
          subject: I18n.t(:report_error_occured_subject),
          html: anything,
          text: anything,
          from_name: anything,
          from_email: anything
        })
      end

      it 'is sent to the user' do
        @mailer.should_receive(:send_email).with({
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

        @mailer.should_receive(:send_email).with({
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
      @mailer.should_receive(:send_email).with({
        to: [{email: EXCEPTIONS_EMAIL}],
        subject: anything,
        html: anything,
        text: anything,
        from_name: anything,
        from_email: anything
      })
    end

    it 'has a subject with the exception message' do
      @mailer.should_receive(:send_email).with({
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
