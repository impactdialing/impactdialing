class UserMailer < MandrillMailer
  def notify_new_signup(user)
    begin
      emailText="<pre>#{user.attributes.to_yaml}</pre>"
      subject="New user signup!"
      response = send_email({
              :subject => subject,
              :html => emailText,
              :text => emailText,
              :from_name => 'Impact Dialing',
              :from_email => FROM_EMAIL,
              :to=>[{email: SALES_EMAIL},{email: TECH_EMAIL}],
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
        #:html => content,
        :from_name => "Admin",
        :from_email => FROM_EMAIL,
        :to => [{email: SALES_EMAIL}, {email: TECH_EMAIL}]
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

  def deliver_download_failure(user, campaign)
    subject = I18n.t(:report_error_occured_subject)
    content = "<br/>#{I18n.t(:report_error_occured)}"
    send_email({
      to: [{ email: user.email }],
      subject: subject,
      text: content,
      html: content,
      from_name: white_labeled_title(user.domain),
      from_email: white_labeled_email(user.domain)
    })
  end

  def deliver_exception_notification(msg, exception)
    content = msg
    content << "<br/><br/>Backtrace:<br/><br/>"+
               "#{exception.backtrace.each{|line| "<br/>#{line}"}}"
    send_email({
      to: [{email: EXCEPTIONS_EMAIL}],
      subject: exception.message,
      text: content,
      html: content,
      from_name: "Exception Notifier",
      from_email: FROM_EMAIL
    })
  end

  def deliver_update_billing_info(account)
    to_list = account.administrators.map {|admin| {email: admin.email}}
    subject = I18n.t(:update_billing_info)
    content = "Your credit card was declined. Please update your <a href='https://admin.impactdialing.com/client/billing'>Billing Information</a>. If your balance fall below $0, you won't be able to make more phone calls. Reply to this message or call #{white_labeled_phone(account.domain_name)} for support."
    send_email({
      :subject => subject,
      :text => content,
      :html => content,
      :from_name => white_labeled_title(account.domain_name),
      :from_email => white_labeled_email(account.domain_name),
      :to => to_list
    })
  end

  def alert_email(subject, content)
    send_email({
      :subject => subject,
      :text => content,
      :from_name => 'impactdialing.com',
      :from_email => FROM_EMAIL,
      :to => [{email: TECH_EMAIL}]
    })
  end

end
