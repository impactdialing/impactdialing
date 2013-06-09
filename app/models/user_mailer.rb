require 'mandrill'
class UserMailer
  include Rails.application.routes.url_helpers
  include WhiteLabeling

  def initialize
    @mandrill = Mandrill::API.new(MANDRILL_API_KEY)
  end

  def white_labeled_email(domain)
    domains = @mandrill.call('senders/domains').collect{|x| x["domain"]}
    if domains.include?(domain)
      super(domain)
    else
      "email@impactdialing.com"
    end
  end


  def send_email(message)
    _params = {:message => message, :async => false}
    return @mandrill.call 'messages/send', _params
  end

  def notify_new_signup(user)
    begin
      emailText="<pre>#{user.attributes.to_yaml}</pre>"
      subject="New user signup!"
      response = send_email({
              :subject => subject,
              :html => emailText,
              :text => emailText,
              :from_name => 'Impact Dialing',
              :from_email => 'email@impactdialing.com',
              :to=>[{email: 'joseph@impactdialing.com'},{email: 'nikhil@impactdialing.com'}],
              :track_opens => true,
              :track_clicks => true
              })
      rescue Exception => e
        logger.error(e.inspect)
    end
  end


  def welcome_email(user)
    begin
      emailText="<p>Hi #{user.fname}! I think you're going love Impact Dialing, so I want to make you an offer: for the next two weeks, you can make up to 100 minutes of phone calls on us.</p>
      <p>I could write pages about how we're different - incredible ease-of-use,  fanatical service, unmatched scalability - but I think you'll enjoy using Impact Dialing more than reading about it. So head to <a href=""https://admin.impactdialing.com/"">admin.impactdialing.com</a> and get calling before your 2 weeks are up!</p>

      <p>Also, I love hearing from our current and prospective clients. Whether it's a question, feature request, or just a note about how you're using Impact Dialing, reply to this email to let me know.</p>
      --<br/>
      Michael Kaiser-Nyman<br/>
      Founder & CEO, Impact Dialing<br/>
      (415) 347-5723      <br/>
      <p>P.S. Don't wait until it's too late - start your 2-week free trial now at <a href=""https://admin.impactdialing.com/"">admin.impactdialing.com</a>.</p>"
      subject="Test drive Impact Dialing until " + (Date.today + 14).strftime("%B %e")

      response = send_email({
              :subject => subject,
              :html => emailText,
              :text => emailText,
              :from_name => 'Michael Kaiser-Nyman, Impact Dialing',
              :from_email => 'email@impactdialing.com',
              :to => [{email: user.email}],
              :bcc_address=>'michael@impactdialing.com',
              :track_opens => true,
              :track_clicks => true
      })
      rescue Exception => e
        logger.error(e.inspect)
    end

  end

  def deliver_invitation(new_user, current_user)
    link = reset_password_url(protocol: PROTOCOL, :host => "admin.#{current_user.domain}", :reset_code => new_user.password_reset_code)
    send_email({
        :subject => I18n.t(:admin_invite_subject, :title => white_labeled_title(current_user.domain)),
        :html => I18n.t(:admin_invite_body_html, :title => white_labeled_title(current_user.domain), :link => link),
        :text => I18n.t(:admin_invite_body_text, :title => white_labeled_title(current_user.domain), :link => link),
        :from_name => white_labeled_title(current_user.domain),
        :from_email => white_labeled_email(current_user.domain),
        :to => [{email: new_user.email}],
        :track_opens => true,
        :track_clicks => true
    })
  end

  def reset_password(user)
      emailText="Click here to reset your password<br/> #{ reset_password_url(protocol: PROTOCOL, :host => "admin.#{user.domain}", :reset_code => user.password_reset_code) }"
      response = send_email({
            :subject => "#{white_labeled_title(user.domain)} password recovery",
            :html => emailText,
            :text => emailText,
            :from_name => white_labeled_title(user.domain),
            :from_email => white_labeled_email(user.domain),
            :to => [{email: user.email}],
            :track_opens => true,
            :track_clicks => true
      })
  end

  def voter_list_upload(response, user_domain, email, voter_list_name)
    unless response['success'].blank?
      subject = I18n.t(:voter_list_upload_succeded_subject, :list_name => voter_list_name)
      content = response['success'].join("<br/>")
    else
      subject = I18n.t(:voter_list_upload_failed_subject, :list_name => voter_list_name)
      content = response['errors'].join("<br/>")
    end
    send_email({
        :subject => subject,
        :html => content,
        :from_name => white_labeled_title(user_domain),
        :from_email => white_labeled_email(user_domain),
        :to => [{email: email}]
    })
  end

  def deliver_admin_report(from, to, content)
    send_email({
        :subject => "Admin report. From: #{from}, To: #{to}",
        :text => content,
        :html => content,
        :from_name => "Admin",
        :from_email => "michael@impactdialing.com",
        :to => [{email: "michaelrkn@gmail.com"}]
    })
  end

  def deliver_download(user, download_link)
    subject = I18n.t(:report_ready_for_download)

    content = "<br/>The report you requested for is ready for download. Follow this link to retrieve it :: <br/> #{download_link}<br/> Please note that this link expires in 24 hours."
    send_email({
        :subject => subject,
        :text => content,
        :html => content,
        :from_name => white_labeled_title(user.domain),
        :from_email => white_labeled_email(user.domain),
        :to => [{email: user.email}]
    })
  end

  def deliver_download_failure(user, campaign, account_id, exception)
    subject = I18n.t(:report_error_occured_subject)
    content = "<br/>#{I18n.t(:report_error_occured)}"
    exception_content = "Campaign: #{campaign.name}  Account Id: #{account_id}. Error details : <br/><br/> #{exception.backtrace.each{|line| "<br/>#{line}"}}"
    send_email({ :subject => subject, :text => content, :html => content, :from_name => white_labeled_title(user.domain), :from_email => white_labeled_email(user.domain), :to => [{email: user.email}]})
    send_email({ :subject => subject, :text => exception_content, :html => exception_content, :from_name => white_labeled_title(user.domain), :from_email => 'email@impactdialing.com',
      :to => [{email: 'nikhil@activesphere.com'},{email: 'michael@impactdialing.com'}]})
  end

  def alert_email(subject, content)
    send_email({ :subject => subject, :text => content, :from_name => 'impactdialing.com', :from_email => 'email@impactdialing.com',
      :to => [{email: 'nikhil@activesphere.com'},{email: 'michael@impactdialing.com'}]})
  end

end
