require 'rails_helper'

feature 'Answer Reports', reports: true do
  include FakeCallData

  let!(:admin){ create(:user) }
  let!(:account){ admin.account }
  let!(:campaign){ create_campaign_with_transfer_attempts(:bare_preview, account)[:campaign] }

  context 'Campaign' do
    let(:page_title){ "#{campaign.name} Answered Calls Report" }
    let(:answers_query){ Answer.where(campaign_id: campaign.id) }
    let(:target_url){ answer_client_reports_path(campaign_id: campaign.id) }

    before do
      web_login_as(admin)
    end

    it_behaves_like 'any form with date picker'
    it_behaves_like 'any answer report'

    context 'transfer stats' do
      let(:transfers){ campaign.transfer_attempts.map(&:transfer).uniq }

      scenario 'display number & percentage of transfers completed to each target' do
        numbers = campaign.transfer_attempts.group('transfer_id').count
        total   = campaign.transfer_attempts.count

        visit target_url

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
    end

    context 'display message drop stats' do
      let(:recording){ create(:bare_recording) }
      let(:call_attempts){ campaign.call_attempts }
      before do
        call_attempts.limit(3).update_all({
          recording_id: recording.id,
          recording_delivered_manually: false
        })
        visit target_url
      end
      scenario 'View stats on the number & percentage of messages left automatically' do
        drops   = campaign.call_attempts.where('recording_id is not null').where(recording_delivered_manually: false)
        numbers = drops.group('recording_id').count
        total   = campaign.answers.count

        i = 1
        Recording.where(1).to_a.each do |recording|
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
  end

  context 'Caller' do
    let(:caller_record){ campaign.callers.to_a.find{|c| c.caller_sessions.count > 0} }
    let(:answers_query){ Answer.where(caller_id: caller_record.id) }
    let(:page_title){ "Answered Calls Report for #{caller_record.username}" }
    let(:target_url){ call_details_client_caller_path(caller_record) }

    before do
      web_login_as(admin)
    end

    it_behaves_like 'any form with date picker'
    it_behaves_like 'any answer report'
  end
end
