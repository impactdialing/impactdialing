require 'mandrill'
class MandrillMailer
  include Rails.application.routes.url_helpers
  include WhiteLabeling

  def initialize(*args)
    @mandrill = Mandrill::API.new(MANDRILL_API_KEY)
  end

  def white_labeled_email(domain)
    domains = @mandrill.call('senders/domains').collect{|x| x["domain"]}
    if domains.include?(domain)
      super(domain)
    else
      FROM_EMAIL
    end
  end

  def send_email(message)
    _params = {:message => message, :async => false}
    return @mandrill.call 'messages/send', _params
  end
end
