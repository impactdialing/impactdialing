class CallFlow::Web::Data
  attr_reader :script

private
  def util
    CallFlow::Web::Util
  end

  def fields(data)
    hard_whitelist = whitelist.select{|val| VoterList::VOTER_DATA_COLUMNS.values.include?(val)}
    clean = util.filter(hard_whitelist, data)
    if clean.empty? or clean.keys == [:id]
      if data[:first_name].present?
        clean[:first_name] = data[:first_name]
      end

      if data[:last_name].present?
        clean[:last_name] = data[:last_name]
      end

      if clean.empty? or clean.keys == [:id]
        # no first or last name...
        clean[:use_id] = '1'
      end
    end

    clean
  end

  def custom_fields(data)
    custom_whitelist = whitelist - VoterList::VOTER_DATA_COLUMNS.values
    util.filter(custom_whitelist, data)
  end

  def contact_fields
    @contact_fields ||= CallFlow::Web::ContactFields::Selected.new(script)
  end

  def whitelist
    @whitelist ||= contact_fields.data
  end

public
  def initialize(script)
    @script = script
  end

  def build(house)
    if house.present?
      members = house['leads'].map do |member|
        {
          id:            member['uuid'],
          fields:        fields(member),
          custom_fields: custom_fields(member)
        }
      end
      data = {
        phone: house['phone'],
        members: members
      }
    else
      data = {campaign_out_of_leads: true}
    end

    data
  end
end

