require 'rails_helper'
require 'repair'

describe Repair::DuplicateLeads do
  let(:campaign){ create(:power) }
  let(:dial_queue){ campaign.dial_queue }
  let(:phone){ '5554321268' }
  let(:redis){ dial_queue.households.redis }

  describe  '.new(dial_queue, phone, detect_duplicates_on=:uuid)' do
    subject{ Repair::DuplicateLeads }

    it 'loads household for given phone' do
      obj = subject.new(dial_queue, phone)
      expect(obj.household).to be_kind_of Hash
    end
    it 'inits duplicates_detected to false' do
      obj = subject.new(dial_queue, phone)
      expect(obj.duplicates_detected).to be_falsey
    end
  end

  describe 'fixing the data' do
    subject{ Repair::DuplicateLeads.new(dial_queue, phone) }
    let(:uuid){ UUID.new }
    let(:dup_uuid){ uuid.generate }
    let(:dup_count){ 4 }
    let(:dup_leads) do
      a = []
      (dup_count).times do |n|
        a << {
          phone: phone,
          uuid: dup_uuid,
          first_name: Forgery(:name).first_name,
          last_name: Forgery(:name).last_name,
          voter_list_id: 42
        }
      end
      a
    end
    let(:uniq_lead) do
      {
        phone: phone,
        uuid: uuid.generate,
        first_name: Forgery(:name).first_name,
        last_name: Forgery(:name).last_name,
        voter_list_id: 42
      }
    end
    let(:leads) do
      dup_leads + [uniq_lead]
    end
    let(:household) do
      {
        sequence: 1,
        uuid: uuid.generate,
        phone: phone,
        score: 1,
        blocked: 0,
        account_id: campaign.account_id,
        campaign_id: campaign.id,
        leads: leads
      }
    end

    shared_context 'unique leads' do
      let(:phone){ '4448421928' }
      let(:clean_leads) do
        [
          {
            phone: phone,
            uuid: uuid.generate,
            first_name: Forgery(:name).first_name,
            last_name: Forgery(:name).last_name,
            voter_list_id: 42
          },
          {
            phone: phone,
            uuid: uuid.generate,
            first_name: Forgery(:name).first_name,
            last_name: Forgery(:name).last_name,
            voter_list_id: 42
          }
        ]
      end
      let(:clean_household) do
        household.merge({leads: clean_leads})
      end
      before do
        dial_queue.households.save(phone, clean_household)
        subject.dedup_redis
      end
    end

    before do
      dial_queue.households.save(phone, household)
    end

    describe '#dedup_redis' do
      it 'removes duplicate leads from a redis household' do
        subject.dedup_redis

        house = dial_queue.households.find(phone)
        expect(house[:leads].size).to eq 2
        expect(house[:leads].map{|l| l[:uuid]}.uniq.size).to eq 2
      end

      it 'counts number of removed leads per voter_list_id' do
        subject.dedup_redis
        expect(subject.counts[:removed_by_list][42]).to eq 3
      end

      it 'populates self.survivors with leads to keep' do
        subject.dedup_redis
        expect(subject.survivors).to include dup_leads.first
        expect(subject.survivors).to include uniq_lead
        expect(subject.survivors.size).to eq 2
      end
    end

    describe '#update_dial_queue' do
      context 'when no duplicates detected' do
        include_context 'unique leads'
        it 'does nothing' do
          redis.zadd dial_queue.available.keys[:active], 123, phone
          subject.update_dial_queue
          expect(phone).to_not be_in_dial_queue_zset campaign.id, :completed
          expect(phone).to be_in_dial_queue_zset campaign.id, :active
        end
      end
      context 'when duplicates detected' do
        context 'and remaining leads are all complete' do
          before do
            subject.dedup_redis
            allow(subject.households).to receive(:dial_again?).with(phone){ false }
          end
          it 'removes phone from available' do
            redis.zadd dial_queue.available.keys[:active], 123, phone
            subject.update_dial_queue
            expect(phone).to_not be_in_dial_queue_zset campaign.id, :active
          end
          it 'removes phone from recycle bin' do
            redis.zadd dial_queue.recycle_bin.keys[:bin], 321, phone
            subject.update_dial_queue
            expect(phone).to_not be_in_dial_queue_zset campaign.id, :bin
          end
          it 'adds phone to completed, preserving score' do
            bin_key = dial_queue.recycle_bin.keys[:bin]
            com_key = dial_queue.completed.keys[:completed]
            redis.zadd bin_key, 431, phone
            subject.update_dial_queue
            expect(phone).to be_in_dial_queue_zset campaign.id, :completed
            score = redis.zscore com_key, phone
            expect(score).to eq 431
          end
        end
        context 'and one or more remaining leads are not complete' do
          before do
            allow(subject.households).to receive(:dial_again?).with(phone){ true }
          end
          it 'does nothing' do
            redis.zadd dial_queue.available.keys[:active], 123, phone
            subject.update_dial_queue
            expect(phone).to be_in_dial_queue_zset campaign.id, :active
            expect(phone).to_not be_in_dial_queue_zset campaign.id, :completed
          end
        end
      end
    end

    describe '#dedup_sql' do
      let(:household_record) do
        create(:household, {
          account: campaign.account,
          campaign: campaign,
          phone: phone
        })
      end

      context 'no duplicates detected' do
        include_context 'unique leads'
        before do
          voters = []
          clean_household[:leads].each do |lead|
            attrs = {
              campaign_id: campaign.id,
              household_id: household_record.id,
              phone: lead[:phone],
              first_name: lead[:first_name],
              last_name: lead[:last_name],
              voter_list_id: lead[:voter_list_id]
            }
            voters << create(:voter, attrs)
          end
          leads = household[:leads]
          voters.each_with_index{|voter,index| leads[index][:sql_id] = voter.id}
          clean_household[:leads] = leads
          dial_queue.households.save(phone, clean_household)

          subject.dedup_redis
        end
        it 'does nothing' do
          expect{
            subject.dedup_sql
          }.to change{ household_record.voters.count }.by 0
        end
      end

      context 'duplicates detected' do
        before do
          first_voter = nil
          dup_leads.each do |lead|
            attrs = {
              campaign_id: campaign.id,
              household_id: household_record.id,
              phone: lead[:phone],
              first_name: lead[:first_name],
              last_name: lead[:last_name],
              voter_list_id: lead[:voter_list_id]
            }
            voter = create(:voter, attrs)
            first_voter ||= voter
          end
          dup_leads.map!{|lead| lead[:sql_id] = first_voter.id; lead}

          voter = create(:voter, {
            campaign_id: campaign.id,
            household_id: household_record.id,
            phone: uniq_lead[:phone],
            first_name: uniq_lead[:first_name],
            last_name: uniq_lead[:last_name],
            voter_list_id: uniq_lead[:voter_list_id]
          })
          uniq_lead[:sql_id] = voter.id
          household[:leads] = dup_leads + [uniq_lead]

          dial_queue.households.save(phone, household)

          subject.dedup_redis
        end

        it 'destroys Voter records of de-duplicated redis leads' do
          expect(household_record.voters.count).to eq household[:leads].size
          expect{
            subject.dedup_sql
          }.to change{ household_record.voters.count }.by -3
        end
      end
    end
  end
end
