require 'spec_helper'

describe 'CallFlow::Web::Data' do
  let(:script){ double('Script', {id: 42}) }

  subject{ CallFlow::Web::Data.new(script) }

  describe 'build(house)' do
    it 'returns a hash like {campaign_out_of_leads: true} when house is nil' do
      expect(subject.build(nil)).to eq({campaign_out_of_leads: true})
    end

    it 'by default returns a hash like {id: 42, fields: {phone: 1234567890}, custom_fields: {}}, "Phone_flag" => true}' do
      house = {
        phone: Forgery(:address).phone,
        voters: [
          {
            id: 42,
            fields: {
              id: 42, first_name: Forgery(:name).first_name, last_name: Forgery(:name).last_name
            },
            custom_fields: {
              'MoreInfo' => 'Call xxx-yyy-zzzz', 'PreviousContribution' => '75'
            }
          },
          {
            id: 43,
            fields: {
              id: 43, first_name: Forgery(:name).first_name, last_name: Forgery(:name).last_name
            },
            custom_fields: {
              'MoreInfo' => 'Call xxx-yyy-zzzz', 'PreviousContribution' => '43'
            }
          },
          {
            id: 44,
            fields: {
              id: 44, first_name: Forgery(:name).first_name, last_name: Forgery(:name).last_name
            },
            custom_fields: {
              'MoreInfo' => 'Call xxx-yyy-zzzz', 'PreviousContribution' => '123'
            }
          }
        ]
      }
      expect(subject.build(house)).to eq({
        id: 42,
        fields: {
          id: 42,
          phone: house[:phone]
        },
        custom_fields: {},
        'Phone_flag' => true
      })
    end
  end
end
