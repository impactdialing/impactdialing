module CampaignHelper
  def options_for_select_campaign_type(campaign)
    options = []
    if can? :manage, Preview
      options << Campaign::Type::PREVIEW
    end
    if can? :manage, Power
      options << Campaign::Type::POWER
    end
    if can? :manage, Predictive
      options << Campaign::Type::PREDICTIVE
    end
    options.map!{|o| [o,o]}
    options_for_select options, campaign.type
  end

  def am_pm_hour_select(field_name)
    select_tag(field_name,options_for_select([
        ["1 AM", "01"],["2 AM", "02"],["3 AM", "03"],["4 AM", "04"],["5 AM", "05"],["6 AM", "06"],
        ["7 AM", "07"],["8 AM", "08"],["9 AM", "09"],["10 AM", "10"],["11 AM", "11"],["Noon", "12"],
        ["1 PM", "13"],["2 PM", "14"],["3 PM", "15"],["4 PM", "16"],["5 PM", "17"],["6 PM", "18"],
        ["7 PM", "19"],["8 PM", "20"],["9 PM", "21"],["10 PM", "22"],["11 PM", "23"],["Midnight", "0"]]))
  end

  def hours
    [["1 AM", "1"],["2 AM", "2"],["3 AM", "3"],["4 AM", "4"],["5 AM", "5"],["6 AM", "6"],
    ["7 AM", "7"],["8 AM", "8"],["9 AM", "9"],["10 AM", "10"],["11 AM", "11"],["Noon", "12"],
    ["1 PM", "13"],["2 PM", "14"],["3 PM", "15"],["4 PM", "16"],["5 PM", "17"],["6 PM", "18"],
    ["7 PM", "19"],["8 PM", "20"],["9 PM", "21"],["10 PM", "22"],["11 PM", "23"],["Midnight", "0"],]
  end

  def voters_remaining_count_for(list)
    blocked_numbers = list.campaign.account.blocked_numbers.for_campaign(list.campaign).pluck(:number)
    return Voter.remaining_voters_for_voter_list(list, blocked_numbers).count
  end

  def voters_available_count_for(list)
    list.voters.available_list(list.campaign).count
  end

  def numbers_count_for(list)
    list.voters.select('DISTINCT(phone)').count
  end

  def numbers_remaining_count_for(list)
    blocked_numbers = list.campaign.account.blocked_numbers.for_campaign(list.campaign).pluck(:number)
    Voter.remaining_voters_for_voter_list(list, blocked_numbers).select('DISTINCT(phone)').count
  end

  def numbers_available_count_for(list)
    list.voters.available_list(list.campaign).select('DISTINCT(phone)').count
  end
end