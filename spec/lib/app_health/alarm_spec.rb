require 'rails_helper'
require 'app_health/alarm'

describe 'AppHealth::Alarm' do  
  subject{ AppHealth::Alarm.new }
  describe '.notify_pager_duty' do
    let(:pager_duty_events_url){ "https://events.pagerduty.com/generic/2010-04-15/create_event.json" }

    it 'sends an event to PagerDuty' do
      VCR.use_cassette('pagerduty recycle rate alert') do
        subject.notify_pager_duty('key', 'description', 'details')
        expect(WebMock).to have_requested(:post, pager_duty_events_url)
      end
    end
  end
end