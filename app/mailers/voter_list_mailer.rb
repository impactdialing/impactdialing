class VoterListMailer < MandrillMailer
  attr_reader :email, :campaign, :voter_list

private
  def format_date(datetime)
    t = DateTime.parse(datetime)
    t.in_time_zone(campaign.time_zone).strftime("%b%e %Y")
  end

public
  def initialize(email, voter_list)
    super
    @email      = email
    @voter_list = voter_list
    @campaign   = voter_list.campaign
    @account    = voter_list.account
  end

  def completed(upload_stats)
    renderer = VoterListRender.new
    html     = renderer.completed(:html, upload_stats)
    text     = renderer.completed(:text, upload_stats)
    subject  = "Upload complete: #{voter_list.name}"
    to       = [{email: email}]

    send_voter_list_email(to, subject, text, html)
  end

  def failed(errors)
    renderer = VoterListRender.new
    html     = renderer.failed(:html, errors)
    text     = renderer.failed(:text, errors)
    subject  = "Upload failed: #{voter_list.name}"
    to       = [{email: email}]

    send_voter_list_email(to, subject, text, html)
  end

  def send_voter_list_email(to, subject, text, html)
    if Rails.env.development?
      print "Sending account usage report: To[#{to}] Subject[#{subject}]\n"
      print "Body text:\n"
      print text
      print "\n"
      print "Body HTML:\n"
      print html
      print "\n"
    end

    send_email({
      :subject      => subject,
      :html         => html,
      :text         => text,
      :from_name    => 'Impact Dialing',
      :from_email   => FROM_EMAIL,
      :to           => to,
      :track_opens  => true,
      :track_clicks => true
    })
  end
end
