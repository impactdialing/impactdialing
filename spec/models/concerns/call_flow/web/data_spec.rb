require 'rails_helper'

describe 'CallFlow::Web::Data' do
  let(:script){ create(:script) }
  let(:house) do
    HashWithIndifferentAccess.new({
      phone: Forgery(:address).phone,
      leads: [
        {
          uuid: 42,
          first_name: Forgery(:name).first_name,
          last_name: Forgery(:name).last_name,
          'MoreInfo' => 'Call xxx-yyy-zzzz',
          'PreviousContribution' => '75'
        },
        {
          uuid: 43,
          first_name: Forgery(:name).first_name,
          last_name: Forgery(:name).last_name,
          'MoreInfo' => 'Call xxx-yyy-zzzz',
          'PreviousContribution' => '43'
        },
        {
          uuid: 44,
          first_name: Forgery(:name).first_name,
          last_name: Forgery(:name).last_name,
          'MoreInfo' => 'Call xxx-yyy-zzzz',
          'PreviousContribution' => '123'
        }
      ]
    })
  end

  let(:nameless_house) do
    HashWithIndifferentAccess.new({
      phone: Forgery(:address).phone,
      leads: [
        {
          uuid: 42,
          'MoreInfo' => 'Call xxx-yyy-zzzz',
          'PreviousContribution' => '75'
        },
        {
          uuid: 43,
          'MoreInfo' => 'Call xxx-yyy-zzzz',
          'PreviousContribution' => '43'
        },
        {
          uuid: 44,
          'MoreInfo' => 'Call xxx-yyy-zzzz',
          'PreviousContribution' => '123'
        }
      ]
    })
  end

  subject{ CallFlow::Web::Data.new(script) }

  describe 'build(house)' do
    it 'returns a hash like {campaign_out_of_leads: true} when house is nil' do
      expect(subject.build(nil)).to eq({campaign_out_of_leads: true})
    end

    it 'by default returns a hash with house properties :phone, :members' do
      expect(subject.build(house)).to eq({
        phone: house[:phone],
        members: [
          {
            id:     house[:leads][0][:uuid],
            fields: {
              'first_name' => house[:leads][0][:first_name],
              'last_name' =>  house[:leads][0][:last_name]
            },
            custom_fields: {}
          },
          {
            id:     house[:leads][1][:uuid],
            fields: {
              'first_name' => house[:leads][1][:first_name],
              'last_name' =>  house[:leads][1][:last_name]
            },
            custom_fields: {}
          },
          {
            id:     house[:leads][2][:uuid],
            fields: {
              'first_name' => house[:leads][2][:first_name],
              'last_name' =>  house[:leads][2][:last_name]
            },
            custom_fields: {}
          }
        ]
      })
    end

    it 'returns a similar hash w/ `use_id` set for members w/ no first or last names' do
      expect(subject.build(nameless_house)).to eq({
        phone: nameless_house[:phone],
        members: [
          {
            id:     nameless_house[:leads][0][:uuid],
            fields: {
              'use_id' => '1'
            },
            custom_fields: {}
          },
          {
            id:     nameless_house[:leads][1][:uuid],
            fields: {
              'use_id' => '1'
            },
            custom_fields: {}
          },
          {
            id:     nameless_house[:leads][2][:uuid],
            fields: {
              'use_id' => '1'
            },
            custom_fields: {}
          }
        ]
      })
    end
  end
end
