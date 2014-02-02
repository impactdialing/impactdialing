class ExceptionMailer < MandrillMailer
  attr_reader :exception

  def initialize(exception)
    @exception = exception
  end

  def deadlock_detected?
    msg = /.*Deadlock found when trying to get lock.*/
    return exception.message =~ msg
  end

  def notify_if_deadlock_detected
    deadlock_detected if deadlock_detected?
  end

  def deadlock_detected
    begin
      innodb_status = ActiveRecord::Base.connection.execute('SHOW ENGINE INNODB STATUS').first
      status_text   = innodb_status.join("\n")
      email_text    = "#{exception.message}\n#{status_text}"
      email_html    = "<p>#{exception.message}</p><pre>#{status_text}</pre>"
      subject       = 'Deadlock detected'
      send_email({
        :subject => subject,
        :html => email_html,
        :text => email_text,
        :from_name => 'Exceptions',
        :from_email => FROM_EMAIL,
        :to => [{email: EXCEPTIONS_EMAIL}],
        :track_opens => false,
        :track_clicks => false
      })
    rescue Exception => e
      Rails.logger.error(e.inspect)
    end
  end
end
