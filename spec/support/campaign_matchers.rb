RSpec::Matchers.define :invalidate_recycle_rate do |recycle_rate|
  match do |campaign|
    campaign.recycle_rate = recycle_rate
    recycle_rate_error    = "#{I18n.t('activerecord.attributes.campaign.recycle_rate')} must be a number between 1 & 72"
    campaign.valid?

    campaign.errors.full_messages.include?(recycle_rate_error)
  end
end

# RSpec::Matchers.define :gather do |gather_options|
#   match do |actual|
#     twiml = Twilio::TwiML::Response.new do |r|
#       r.Gather(gather_options) do
#         if @say_texts.present?
#           @say_texts.each do |say_text|
#             r.Say say_text
#           end
#         end
#       end
#     end.text

#     actual == twiml
#   end

#   chain :with_nested_say do |say_text|
#     @say_texts = [*say_text]
#   end
# end

# RSpec::Matchers.define :say do |say_text|
#   match do |actual|
#     twiml = Twilio::TwiML::Response.new do |r|
#       r.Say say_text
#       if @url.present?
#         r.Redirect @url, @url_options
#       end
#       if @hangup
#         r.Hangup
#       end
#       if @pause_options
#         r.Pause(@pause_options)
#       end
#     end.text

#     actual == twiml
#   end

#   chain :and_redirect do |url, url_options={}|
#     @url         = url
#     @url_options = url_options
#   end

#   chain :and_hangup do
#     @hangup = true
#   end

#   chain :and_pause do |pause_options|
#     @pause_options = pause_options
#   end
# end

# RSpec::Matchers.define :dial_conference do |dial_options, conference_options|
#   match do |actual|
#     twiml = Twilio::TwiML::Response.new do |r|
#       r.Dial(dial_options) do
#         r.Conference(conference_options)
#       end
#     end.text

#     actual == twiml
#   end
# end

# RSpec::Matchers.define :redirect do |url, url_options={}|
#   match do |actual|
#     twiml = Twilio::TwiML::Response.new do |r|
#       r.Redirect(url, url_options)
#     end.text

#     actual == twiml
#   end
# end

# RSpec::Matchers.define :hangup do
#   match do |actual|
#     twiml = Twilio::TwiML::Response.new{|r| r.Hangup}.text

#     actual == twiml
#   end
# end
