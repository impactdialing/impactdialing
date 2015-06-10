require 'rails_helper'

describe 'CallFlow::Web::Data' do
  let(:script){ double('Script', {id: 42}) }
  let(:house) do
    {
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
  end

  let(:nameless_house) do
    {
      phone: Forgery(:address).phone,
      voters: [
        {
          id: 42,
          fields: {
            id: 42
          },
          custom_fields: {
            'MoreInfo' => 'Call xxx-yyy-zzzz', 'PreviousContribution' => '75'
          }
        },
        {
          id: 43,
          fields: {
            id: 43
          },
          custom_fields: {
            'MoreInfo' => 'Call xxx-yyy-zzzz', 'PreviousContribution' => '43'
          }
        },
        {
          id: 44,
          fields: {
            id: 44
          },
          custom_fields: {
            'MoreInfo' => 'Call xxx-yyy-zzzz', 'PreviousContribution' => '123'
          }
        }
      ]
    }
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
            id:     house[:voters][0][:id],
            fields: {
              first_name: house[:voters][0][:fields][:first_name],
              last_name:  house[:voters][0][:fields][:last_name]
            },
            custom_fields: {}
          },
          {
            id:     house[:voters][1][:id],
            fields: {
              first_name: house[:voters][1][:fields][:first_name],
              last_name:  house[:voters][1][:fields][:last_name]
            },
            custom_fields: {}
          },
          {
            id:     house[:voters][2][:id],
            fields: {
              first_name: house[:voters][2][:fields][:first_name],
              last_name:  house[:voters][2][:fields][:last_name]
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
            id:     nameless_house[:voters][0][:id],
            fields: {
              use_id: '1'
            },
            custom_fields: {}
          },
          {
            id:     nameless_house[:voters][1][:id],
            fields: {
              use_id: '1'
            },
            custom_fields: {}
          },
          {
            id:     nameless_house[:voters][2][:id],
            fields: {
              use_id: '1'
            },
            custom_fields: {}
          }
        ]
      })
    end
  end
end
