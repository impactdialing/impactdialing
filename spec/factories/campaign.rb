FactoryGirl.define do
  factory :bare_preview, class: 'Preview' do
    name         { Forgery(:name).company_name }
    caller_id    '1234567890'
    recycle_rate 1
    start_time   (Time.now - 6.hours)
    end_time     (Time.now - 6.hours)
    time_zone    "Pacific Time (US & Canada)"
  end
end
