RSpec::Matchers.define :gather do |gather_options|
  match do |actual|
    twiml = Twilio::TwiML::Response.new do |r|
      r.Gather(gather_options) do
        if @say_texts.present?
          @say_texts.each do |say_text|
            r.Say say_text
          end
        end
      end
    end.text

    print "Expected: #{twiml}\n\n"

    actual == twiml
  end

  chain :with_nested_say do |say_text|
    @say_texts = [*say_text]
  end
end

RSpec::Matchers.define :say do |say_text|
  match do |actual|
    twiml = Twilio::TwiML::Response.new do |r|
      r.Say say_text
      if @url.present?
        r.Redirect @url, @url_options
      end
      if @hangup
        r.Hangup
      end
    end.text
    print "Expected: #{twiml}\n"
    actual == twiml
  end

  chain :and_redirect do |url, url_options={}|
    @url         = url
    @url_options = url_options
  end

  chain :and_hangup do
    @hangup = true
  end
end

RSpec::Matchers.define :dial_conference do |dial_options, conference_options|
  match do |actual|
    twiml = Twilio::TwiML::Response.new do |r|
      r.Dial(dial_options) do
        r.Conference(conference_options)
      end
    end.text

    actual == twiml
  end
end

RSpec::Matchers.define :redirect do |url, url_options={}|
  match do |actual|
    twiml = Twilio::TwiML::Response.new do |r|
      r.Redirect(url, url_options)
    end.text

    actual == twiml
  end
end

RSpec::Matchers.define :hangup do
  match do |actual|
    twiml = Twilio::TwiML::Response.new{|r| r.Hangup}.text

    actual == twiml
  end
end
