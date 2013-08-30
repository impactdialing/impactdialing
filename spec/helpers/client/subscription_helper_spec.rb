require 'spec_helper'

describe Client::SubscriptionHelper do
  it 'returns a collection of display,value pairs for select options' do
    expected = [
      ["Basic", "Basic"], ["Pro", "Pro"], ["Business", "Business"],
      ["Per minute", "PerMinute"]
    ]
    helper.subscription_type_options_for_select.should eq expected
  end
end