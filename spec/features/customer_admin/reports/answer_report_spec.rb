require 'spec_helper'

feature 'Full Campaign Answer Report' do
  include FakeCallData

  before(:all) do
    @admin    = create(:user)
    @account  = @admin.account
    @campaign = create_campaign_with_transfer_attempts(:bare_preview, @account)[:campaign]
  end

  let(:admin){ @admin }
  let(:account){ @account }
  let(:campaign){ @campaign }

  scenario 'View stats on the number & percentage responses of each type given for each question' do
    web_login_as(admin)
    visit answer_client_reports_path(campaign_id: campaign.id)
    expect(page).to have_content "#{campaign.name} Answered Calls Report"

    question_ids = Answer.select('question_id').all.map(&:question_id)
    i            = 1
    save_and_open_page
    Question.where(id: question_ids).includes(:possible_responses).each do |question|
      expect(page).to have_content("Script: #{question.script.name}")
      expect(page).to have_content("Question #{i}: #{question.text}")
      within("table:nth-of-type(#{i})") do
        question.possible_responses.each do |possible_response|
          answers        = Answer.where(campaign_id: campaign.id)
          answer_count   = answers.group('possible_response_id').count
          answer_total   = answers.group('question_id').count
          answer_perc    = (answer_count[possible_response.id].try(:*, 100) || 0) / answer_total[question.id]
          expected_count = answer_count[possible_response.id] || 0
          expected_perc  = "#{answer_perc} %"

          expect(page).to have_content possible_response.value
          expect(page).to have_content expected_count
          expect(page).to have_content expected_perc
        end
      end
      i += 1
    end

    expect(i > 1).to be_truthy
  end

  scenario 'View stats on the number & percentage of transfers completed to each target' do
    transfers = campaign.transfer_attempts.map(&:transfer).uniq

    web_login_as(admin)
    visit answer_client_reports_path(campaign_id: campaign.id)

    numbers = campaign.transfer_attempts.group('transfer_id').count
    total   = campaign.transfer_attempts.count

    i = 1
    transfers.each do |transfer|
      number = numbers[transfer.id]
      perc   = (number || 0) * 100 / total

      within("#transfer_#{i}") do
        expect(page).to have_content transfer.label
        expect(page).to have_content number
        expect(page).to have_content "#{perc} %"
      end

      i += 1
    end

    expect(i > 1).to be_truthy
  end

  scenario 'View stats on the number & percentage of messages left by callers' do
    recording     = create(:bare_recording)
    call_attempts = campaign.call_attempts
    call_attempts.limit(3).update_all({
      recording_id: recording.id,
      recording_delivered_manually: true
    })

    web_login_as(admin)
    visit answer_client_reports_path(campaign_id: campaign.id)

    drops   = campaign.call_attempts.where('recording_id is not null').where(recording_delivered_manually: true)
    numbers = drops.group('recording_id').count
    total   = campaign.answers.count

    i = 1
    Recording.all.each do |recording|
      number = numbers[recording.id] || 0
      perc   = (number * 100) / total
      within("#recording_#{i}") do
        expect(page).to have_content recording.name
        expect(page).to have_content number
        expect(page).to have_content "#{perc}%"
      end

      i += 1
    end

    expect(i > 1).to be_truthy
  end
end
