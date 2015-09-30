require 'base64'

class VoterListMailer < MandrillMailer
  attr_reader :email, :campaign, :voter_list

private
  def format_date(datetime)
    t = DateTime.parse(datetime)
    t.in_time_zone(campaign.time_zone).strftime("%b%e %Y")
  end

  def build_attachment(invalid_rows, invalid_lines)
    invalid = invalid_rows + invalid_lines
    [{
      type:    'text/plain',
      name:    "InvalidRows #{voter_list.name}.csv",
      content: Base64.encode64(invalid.join)
    }]
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
    renderer   = VoterListRender.new
    html       = renderer.completed(:html, upload_stats)
    text       = renderer.completed(:text, upload_stats)
    subject    = "Upload complete: #{voter_list.name}"
    to         = [{email: email}]
    attachment = []
    
    if upload_stats[:invalid_numbers] > 0
      attachment = build_attachment(upload_stats[:invalid_rows], upload_stats[:invalid_lines])
    end

    send_voter_list_email(to, subject, text, html, attachment)
  end

  def failed(errors)
    renderer = VoterListRender.new
    html     = renderer.failed(:html, errors)
    text     = renderer.failed(:text, errors)
    subject  = "Upload failed: #{voter_list.name}"
    to       = [{email: email}]

    send_voter_list_email(to, subject, text, html)
  end

  def send_voter_list_email(to, subject, text, html, attachments=[])
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
      :attachments  => attachments,
      :track_opens  => true,
      :track_clicks => true
    })
  end
end
