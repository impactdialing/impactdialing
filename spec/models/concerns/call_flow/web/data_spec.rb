require 'rails_helper'

describe 'CallFlow::Web::Data' do
  let(:script) do
    create(:script, {
      voter_fields: [
        'Phone', 'FirstName', 'LastName', 'Email',
        'MoreInfo', 'PreviousContribution'
      ]
    })
  end
  let(:house) do
    HashWithIndifferentAccess.new({
      phone: Forgery(:address).phone,
      leads: [
        {
          uuid: 42,
          first_name: Forgery(:name).first_name,
          last_name: Forgery(:name).last_name,
          email: Forgery(:email).address,
          'MoreInfo' => 'Call xxx-yyy-zzzz',
          'PreviousContribution' => '75'
        },
        {
          uuid: 43,
          first_name: Forgery(:name).first_name,
          last_name: Forgery(:name).last_name,
          email: Forgery(:email).address,
          'MoreInfo' => 'Call xxx-yyy-zzzz',
          'PreviousContribution' => '43'
        },
        {
          uuid: 44,
          first_name: Forgery(:name).first_name,
          last_name: Forgery(:name).last_name,
          email: '<a href="mailto:'+Forgery(:email).address+'">'+Forgery(:email).address+'</a>',
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
    before do
      selected_fields = CallFlow::Web::ContactFields::Selected.new(script)
      selected_fields.cache(script.voter_fields)
    end
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
              'last_name' =>  house[:leads][0][:last_name],
              'email' => '<a target="_blank" href="mailto:'+house[:leads][0][:email]+'">'+house[:leads][0][:email]+'</a>'
            },
            custom_fields: {
              'MoreInfo' => 'Call xxx-yyy-zzzz',
              'PreviousContribution' => '75'
            }
          },
          {
            id:     house[:leads][1][:uuid],
            fields: {
              'first_name' => house[:leads][1][:first_name],
              'last_name' =>  house[:leads][1][:last_name],
              'email' => '<a target="_blank" href="mailto:'+house[:leads][1][:email]+'">'+house[:leads][1][:email]+'</a>'
            },
            custom_fields: {
              'MoreInfo' => 'Call xxx-yyy-zzzz',
              'PreviousContribution' => '43'
            }
          },
          {
            id:     house[:leads][2][:uuid],
            fields: {
              'first_name' => house[:leads][2][:first_name],
              'last_name' =>  house[:leads][2][:last_name],
              'email' => house[:leads][2][:email]
            },
            custom_fields: {
              'MoreInfo' => 'Call xxx-yyy-zzzz',
              'PreviousContribution' => '123'
            }
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
              :use_id => '1'
            },
            custom_fields: {
              'MoreInfo' => 'Call xxx-yyy-zzzz',
              'PreviousContribution' => '75'
            }
          },
          {
            id:     nameless_house[:leads][1][:uuid],
            fields: {
              :use_id => '1'
            },
            custom_fields: {
              'MoreInfo' => 'Call xxx-yyy-zzzz',
              'PreviousContribution' => '43'
            }
          },
          {
            id:     nameless_house[:leads][2][:uuid],
            fields: {
              :use_id => '1'
            },
            custom_fields: {
              'MoreInfo' => 'Call xxx-yyy-zzzz',
              'PreviousContribution' => '123'
            }
          }
        ]
      })
    end
  end
end
