require 'spec_helper'

describe CallStats::Velocity do
  # let(:campaign){ create(:power) }
  before(:all) do
    @campaign_for_all = create(:power)
    create_list(:caller, rand(10) + 2, {
      campaign: @campaign_for_all
    })
    create_list(:webui_caller_session, rand(10) + 1, {
      campaign: @campaign_for_all,
      caller: Caller.all.sample,
      tDuration: rand(60*20) + 1200 # <= at least 5 minutes each session
    })
    create_list(:phones_only_caller_session, rand(10) + 1, {
      campaign: @campaign_for_all,
      caller: Caller.all.sample,
      tDuration: rand(60*20) + 1200 # <= at least 5 minutes each session
    })
    create_list(:call_attempt, rand(100) + 20, {
      campaign: @campaign_for_all,
      caller_session: CallerSession.all.sample,
      tDuration: rand(60*20) + 60 # <= at least 1 minute each session
    })
  end

  after(:all) do
    Campaign.destroy_all
    CallerSession.destroy_all
    CallAttempt.destroy_all
  end

  subject{ CallStats::Velocity.new(@campaign_for_all) }

  describe '#dial_rate' do
    it 'returns an Integer indicating the number of dials made per caller per hour' do
      dials           = CallAttempt.count
      calling_seconds = CallerSession.sum('tDuration')
      calling_hours   = (calling_seconds / 3600.0)
      calling_hours   = calling_hours < 1 ? 1 : calling_hours
      expected        = (dials / calling_hours).round
      expect(subject.dial_rate).to eq expected
    end

    it 'can be limited to a date range via options to .new; e.g. .new(campaign, options)' do
      from_date = 5.days.ago
      to_date   = 3.days.ago
      # make sure some records are excluded
      attempts = CallAttempt.order('id').limit(CallAttempt.count / 2).update_all(created_at: 4.days.ago)
      sessions = CallerSession.order('id').limit(CallerSession.count / 2).update_all(created_at: 4.days.ago)

      dials           = CallAttempt.between(from_date, to_date).count
      calling_seconds = CallerSession.between(from_date, to_date).sum('tDuration')
      calling_hours   = (calling_seconds / 3600.0)
      calling_hours   = calling_hours < 1 ? 1 : calling_hours
      expected        = (dials / calling_hours).round

      velocity = CallStats::Velocity.new(@campaign_for_all, {from_date: from_date, to_date: to_date})
      expect(velocity.dial_rate).to eq expected
    end
  end

  describe '#answer_rate' do
    it 'returns an Integer indicating the number of answered calls made per caller per hour' do
      CallAttempt.order('id').limit(CallAttempt.count / 2).update_all(status: CallAttempt::Status::SUCCESS)

      dials           = CallAttempt.count
      answers         = CallAttempt.where(status: CallAttempt::Status::SUCCESS).count
      calling_seconds = CallerSession.sum('tDuration')
      calling_hours   = (calling_seconds / 3600.0)
      expected        = (answers / calling_hours).round

      expect(subject.answer_rate).to eq expected
    end
  end

  describe '#average_call_length' do
    it 'returns an Integer indicating the average length of conversations' do
      CallAttempt.order('id').limit(CallAttempt.count / 2).update_all(status: CallAttempt::Status::SUCCESS)

      dials           = CallAttempt.count
      answers         = CallAttempt.where(status: CallAttempt::Status::SUCCESS)

      seconds  = (answers.sum('tDuration') / answers.count).ceil
      remaining = seconds
      hours = (seconds / 3600.0).floor
      remaining -= hours * 3600
      minutes = (remaining / 60.0).floor
      remaining -= minutes * 60
      seconds = remaining
      remaining -= seconds
      expected = ''
      expected += "#{hours} #{'hour'.pluralize(hours)} " if hours > 0
      expected += "#{minutes} #{'minute'.pluralize(minutes)} #{seconds} #{'second'.pluralize(seconds)}"

      expect(subject.average_call_length).to eq expected
    end
  end
end
