require 'rails_helper'

describe 'CallList::DisabledTrimmer' do
  include ListHelpers

  let(:campaign) do
    create(:preview)
  end
  let(:list_one) do
    create(:voter_list, campaign: campaign)
  end
  let(:list_two) do
    create(:voter_list, campaign: campaign)
  end
  let(:with_custom_id){ false }
  let(:households_one) do
    build_household_hashes(1, list_one, with_custom_id)
  end
  let(:households_two) do
    build_household_hashes(1, list_two, with_custom_id)
  end
  let(:parser) do
    double('CallList::Imports::Parser', {
      each_batch: nil
    })
  end
  let(:phone){ households_one.keys.first }
  let(:active_redis_key){ "dial_queue:#{campaign.id}:households:active:111" }
  let(:inactive_redis_key){ "dial_queue:#{campaign.id}:households:inactive:111" }
  let(:recycle_bin_key){ "dial_queue:#{campaign.id}:bin" }
  let(:available_key){ "dial_queue:#{campaign.id}:active" }
  let(:presented_key){ "dial_queue:#{campaign.id}:presented" }
  let(:blocked_key){ "dial_queue:#{campaign.id}:blocked" }
  let(:completed_key){ "dial_queue:#{campaign.id}:completed" }

  describe 'disabling leads' do
    subject{ CallList::DisabledTrimmer.new(list_one) }

    let(:score){ redis.zscore available_key, phone }

    context 'first time disabling given phone/household' do
      before do
        import_list(list_one, households_one)
        import_list(list_two, households_two)
        expect(households_one).to be_in_redis_households(campaign.id, 'active')
        expect(households_two).to be_in_redis_households(campaign.id, 'active')

        score # populate this :let after import
        stub_list_parser(parser, active_redis_key, households_one)
      end

      it 'moves leads associated w/ disabled list to "inactive" namespace' do
        subject.disable_leads
        expect(households_one).to be_in_redis_households(campaign.id, 'inactive')
        expect(households_one).to_not be_in_redis_households(campaign.id, 'active')
      end

      context 'phone has been dialed recently' do
        before do
          redis.zrem available_key, phone
          redis.zadd recycle_bin_key, score, phone
          subject.disable_leads
        end

        it 'stores current score (recycle bin zscore) of phone number' do
          house = redis.hget inactive_redis_key.gsub('111', phone[0..-4]), phone[-3..-1]
          house = JSON.parse house
          expect(house['score'].to_f).to be_within(0.0000001).of score
        end
      end

      context 'phone has been dialed but not recently' do
        before do
          subject.disable_leads
        end

        it 'stores current score (available zscore) of phone number' do
          house = redis.hget inactive_redis_key.gsub('111', phone[0..-4]), phone[-3..-1]
          house = JSON.parse house
          expect(house['score'].to_f).to be_within(0.0000001).of score
        end
      end

      context 'phone number has no active leads from other lists' do
        it 'is removed from available set' do
          expect(phone).to eq households_one.keys.first
          redis.zadd available_key, 1.1, phone
          subject.disable_leads
          expect(phone).to_not be_in_dial_queue_zset(campaign.id, 'active')
        end
        it 'is removed from recycle bin set' do
          redis.zrem available_key, phone
          redis.zadd recycle_bin_key, 1.1, phone
          subject.disable_leads
          expect(phone).to_not be_in_dial_queue_zset(campaign.id, 'bin')
        end
        it 'is removed from blocked set' do
          redis.zrem available_key, phone
          redis.zadd blocked_key, 1.0, phone
          subject.disable_leads
          expect(phone).to_not be_in_dial_queue_zset(campaign.id, 'blocked')
        end
        it 'is removed from completed set' do
          redis.zrem available_key, phone
          redis.zadd completed_key, "#{Time.now.to_i}.000005", phone
          subject.disable_leads
          expect(phone).to_not be_in_dial_queue_zset(campaign.id, 'completed')
        end
      end

      context 'phone number has active leads from other lists' do
        let(:lead_from_another_list){ build_lead_hash(list_two, phone) }
        before do
          households_one[phone][:leads] << lead_from_another_list
          import_list(list_one, households_one)
          expect(households_one).to be_in_redis_households(campaign.id, 'active')
          stub_list_parser(parser, active_redis_key, households_one)
        end

        context 'phone number has incomplete leads' do
          it 'is not removed from available set' do
            subject.disable_leads
            expect(phone).to be_in_dial_queue_zset(campaign.id, 'active')
          end
          it 'is not removed from recycle bin set' do
            redis.zrem available_key, phone
            redis.zadd recycle_bin_key, 1.1, phone
            subject.disable_leads
            expect(phone).to be_in_dial_queue_zset(campaign.id, 'bin')
          end
          it 'is not removed from blocked set' do
            redis.zrem available_key, phone
            redis.zadd blocked_key, 1.0, phone
            subject.disable_leads
            expect(phone).to be_in_dial_queue_zset(campaign.id, 'blocked')
          end
          it 'is not removed from completed set' do
            redis.zrem available_key, phone
            redis.zadd completed_key, 1.1, phone
            subject.disable_leads
            expect(phone).to be_in_dial_queue_zset(campaign.id, 'completed')
          end
        end

        context 'phone number has only completed leads left' do
          before do
            house = campaign.dial_queue.households.find phone
            house['leads'].each do |lead|
              campaign.dial_queue.households.mark_lead_completed(lead['sequence'])
            end
            redis.hset *campaign.dial_queue.households.hkey(phone), house.to_json
          end
          it 'is removed from available set' do
            subject.disable_leads
            expect(phone).to_not be_in_dial_queue_zset(campaign.id, 'active')
          end
          it 'is removed from recycle bin set' do
            redis.zrem available_key, phone
            redis.zadd recycle_bin_key, 1.1, phone
            subject.disable_leads
            expect(phone).to_not be_in_dial_queue_zset(campaign.id, 'bin')
          end
          it 'is removed from presented set' do
            redis.zrem available_key, phone
            redis.zadd presented_key, 1.1, phone
            subject.disable_leads
            expect(phone).to_not be_in_dial_queue_zset(campaign.id, 'presented')
          end
          it 'is added to completed set' do
            subject.disable_leads
            expect(phone).to be_in_dial_queue_zset(campaign.id, 'completed')
          end
        end
      end
    end

    context 'inactive household already exists at same namespace (ie leads in household from other lists already disabled)' do
      context 'leads have custom ids' do
        let(:lead_from_another_list){ build_lead_hash(list_two, phone, 100) }
        let(:lead_from_same_list){ build_lead_hash(list_one, phone, 101) }
        let(:households_one){ build_household_hashes(1, list_one, true) }
        let(:subject_two){ CallList::DisabledTrimmer.new(list_two) }

        before do
          # import 
          households_one[phone][:leads] << lead_from_same_list
          households_one[phone][:leads] << lead_from_another_list
          import_list(list_one, households_one)
          expect(households_one).to be_in_redis_households(campaign.id, 'active')

          # disable
          stub_list_parser(parser, active_redis_key, households_one)

          subject.disable_leads # disables list one
          expect(households_one).to have_leads_from(list_one).in_redis_households(campaign.id, 'inactive')
          subject_two.disable_leads
        end

        it 'preserves existing inactive leads under same household' do
          expect(households_one).to have_leads_from(list_one).in_redis_households(campaign.id, 'inactive')
          expect(households_one).to have_leads_from(list_two).in_redis_households(campaign.id, 'inactive')
        end

        it 'does not duplicate leads w/ matching custom id' do
          inactive_households = redis.hgetall "#{inactive_redis_key.split(':')[0..-2].join(':')}:#{phone[0..-4]}"
          inactive_leads = []
          inactive_households.each{|ph,h| inactive_leads << h['leads']}
          total_inactive_leads = inactive_leads.size
          inactive_leads_with_custom_id = inactive_leads.map{|l| l['custom_id']}.uniq.size
          expect(total_inactive_leads).to eq inactive_leads_with_custom_id
        end
      end

      context 'leads do not have custom ids' do
        let(:lead_from_another_list){ build_lead_hash(list_two, phone) }
        let(:lead_from_same_list){ build_lead_hash(list_one, phone) }
        let(:households_one){ build_household_hashes(1, list_one) }
        let(:households_two){ build_household_hashes(1, list_two) }
        let(:subject_two){ CallList::DisabledTrimmer.new(list_two) }

        before do
          # import 
          households_one[phone][:leads] << lead_from_same_list
          households_one[phone][:leads] << lead_from_another_list
          import_list(list_one, households_one)
          expect(households_one).to be_in_redis_households(campaign.id, 'active')

          # disable
          stub_list_parser(parser, active_redis_key, households_one)

          subject.disable_leads # disables list one
          expect(households_one).to have_leads_from(list_one).in_redis_households(campaign.id, 'inactive')
          subject_two.disable_leads
        end

        it 'adds leads to inactive household' do
          expect(households_one).to have_leads_from(list_one).in_redis_households(campaign.id, 'inactive')
          expect(households_one).to have_leads_from(list_two).in_redis_households(campaign.id, 'inactive')
        end
      end
    end
  end

  describe 'enabling leads' do
    subject{ CallList::DisabledTrimmer.new(list_one) }
    before do
      import_list(list_one, households_one)
      import_list(list_two, households_two)
      expect(households_one).to be_in_redis_households(campaign.id, 'active')
      stub_list_parser(parser, active_redis_key, households_one)
      subject.disable_leads
      expect(households_one).to be_in_redis_households(campaign.id, 'inactive')
    end

    it 'adds leads associated w/ enabled list' do
      subject.enable_leads
      expect(households_one).to be_in_redis_households(campaign.id, 'active')
    end

    context 'phone was completed via message drops' do
      let(:message_drop_key){ campaign.dial_queue.households.keys[:message_drops] }
      let(:household_one_seq){ 1 }
      before do
        campaign.update_attributes!({
          use_recordings: true,
          answering_machine_detect: true,
          call_back_after_voicemail_delivery: false
        })
        redis.setbit(message_drop_key, household_one_seq, 1)
      end

      it 'adds phone to completed set' do
        subject.enable_leads
        expect(phone).to be_in_dial_queue_zset(campaign.id, 'completed')
      end

      it 'does not update phone score when already in completed set' do
        redis.zadd(completed_key, 3.3, phone)
        subject.enable_leads
        expect(redis.zscore(completed_key, phone)).to eq 3.3
      end
    end

    context 'phone has not been completed' do
      it 'is not moved from available set' do
        redis.zadd available_key, 1.1, phone
        subject.enable_leads
        expect(phone).to be_in_dial_queue_zset(campaign.id, 'active')
      end
      it 'is not moved from recycle bin set' do
        redis.zadd recycle_bin_key, 1.1, phone
        redis.zrem available_key, phone
        subject.enable_leads
        expect(phone).to be_in_dial_queue_zset(campaign.id, 'bin')
      end
      it 'is not moved from blocked set' do
        redis.zadd blocked_key, 1.0, phone
        redis.zrem available_key, phone
        subject.enable_leads
        expect(phone).to be_in_dial_queue_zset(campaign.id, 'blocked')
      end
    end

    context 'phone was completed via dispositioned leads but newly enabled list adds incomplete leads' do
      let(:completed_leads_key){ campaign.dial_queue.households.keys[:completed_leads] }
      let(:score){ households_one[phone][:score] }
      let(:leads) do
        k = "#{campaign.dial_queue.households.keys[:inactive]}:#{phone[0..-4]}"
        JSON.parse( redis.hget(k, phone[-3..-1]) )
      end

      before do
        leads['leads'].each do |lead|
          redis.setbit(completed_leads_key, lead['sequence'], 1)
        end
      end

      context 'and newly enabled list adds incomplete leads' do
        before do
          lead = build_lead_hash(list_one, phone) 
          households_one[phone][:leads] << lead
          add_leads(list_one, phone, [lead], 'inactive')
        end

        it 'is removed from completed set' do
          redis.zadd completed_key, score, phone
          subject.enable_leads
          expect(phone).to_not be_in_dial_queue_zset(campaign.id, 'completed')
        end
        
        it 'is added to recycle bin set' do
          subject.enable_leads
          expect(phone).to be_in_dial_queue_zset(campaign.id, 'bin')
        end

        it 'uses the current household.score' do
          subject.enable_leads
          expect(phone).to have_zscore(score).in_dial_queue_zset(campaign.id, 'bin') 
        end
      end

      context 'phone was completed via dispositioned leads and no incomplete leads are added from enabled list' do
        it 'is added to completed zset' do
          subject.enable_leads
          expect(phone).to be_in_dial_queue_zset(campaign.id, 'completed')
        end
      end
    end
  end
end

