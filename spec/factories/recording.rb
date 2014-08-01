FactoryGirl.define do
  factory :bare_recording, class: 'Recording' do
    name { Forgery(:basic).text }
    active { true }
    file_file_name { "#{Forgery(:basic).text}.mp3" }
    file_content_type 'audio/mpeg'
    file_file_size { Forgery(:basic).number }
  end
end