require 'spec_helper'

describe ExceptionMailer, :type => :mailer do
  describe 'mailer = ExceptionMailer.new(exception)' do
    it 'sets exception on the instance' do
      expect(ExceptionMailer.new('Blah').exception).to eq 'Blah'
    end
  end

  describe 'mailer.notify_if_deadlock_detected' do
    let(:msg) do
      'Mysql2::Error: Deadlock found when trying to get lock; try restarting transaction: UPDATE `voters` SET `enabled` = 0 WHERE `voters`.`id` IN (123, 321)'
    end
    let(:exception) do
      ActiveRecord::StatementInvalid.new(msg)
    end
    let(:mailer) do
      ExceptionMailer.new(exception)
    end
    let(:status_msg) do
      [['INNODB STATUS OUTPUT', 'LATEST DETECTED DEADLOCK']]
    end
    before do
      allow(ActiveRecord::Base.connection).to receive(:execute).
        with('SHOW ENGINE INNODB STATUS').
        and_return(status_msg)
    end
    it 'sends an email to EXCEPTION_EMAIL with the exception message and innodb status' do
      email_text = "#{msg}\n#{status_msg.first.join("\n")}"
      email_html = "<p>#{msg}</p><pre>#{status_msg.first.join("\n")}</pre>"
      expect(mailer).to receive(:send_email).with({
        :subject => anything,
        :html => email_html,
        :text => email_text,
        :from_name => anything,
        :from_email => anything,
        :to => [{email: EXCEPTIONS_EMAIL}],
        :track_opens => false,
        :track_clicks => false
      })
      mailer.notify_if_deadlock_detected
    end
  end
end
