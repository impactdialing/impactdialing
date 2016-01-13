require 'rails_helper'

describe CallList::Prune::Leads do
  include ListHelpers
  let(:campaign){ create(:predictive) }
  let(:voter_list) do
    create(:voter_list, {
      campaign: campaign,
      purpose: 'import'
    })
  end
  let(:prune_voter_list) do
    create(:voter_list, {
      campaign: campaign,
      purpose: 'prune_leads'
    })
  end
  let(:households) do
    build_household_hashes(5, voter_list, true, true)
  end
  let(:first_ids) do
    households.keys.map do |k|
      households[k][:leads].first[:custom_id]
    end
  end
  let(:all_ids) do
    households.keys.map do |k|
      households[k][:leads].map{|lead| lead[:custom_id]}
    end.flatten
  end
  let(:ids_to_delete) do
    first_ids[0..3].map(&:to_s)
  end
  let(:ids_to_keep) do
    first_ids[4..-1].map(&:to_s)
  end
  let(:leads_count) do
    n = 0
    households.each{|ph,h| n += h[:leads].size}
    n
  end

  before do
    import_list(voter_list, households, 'active', 'active')
  end

  describe '#delete_leads(key_id_pairs)' do
    subject{ CallList::Prune::Leads.new(prune_voter_list) }
    let(:key_id_pairs) do
      ids_to_delete.map do |id|
        [id, voter_list.campaign.call_list.custom_id_register_key(id)]
      end
    end
    it 'removes leads w/ matching ids' do
      subject.delete_leads(key_id_pairs)
      expect(ids_to_delete).to_not belong_to_active_leads
    end
    it 'de-registers the removed leads custom ids' do
      subject.delete_leads(key_id_pairs)
      expect(ids_to_delete).to_not be_registered_as_custom_ids
    end
    it 'does not remove leads w/out matching ids' do
      subject.delete_leads(key_id_pairs)
      expect(ids_to_keep).to belong_to_active_leads
    end

    context 'all households have leads remaining' do
      it 'returns [removed_lead_count, phone_numbers_with_all_leads_deleted]' do
        phone_numbers_with_all_leads_deleted = []
        households.each do |ph,h|
          if h[:leads].all?{|lead| ids_to_delete.include?(lead[:custom_id]) }
            phone_numbers_with_all_leads_deleted << ph
          end
        end
        actual = subject.delete_leads(key_id_pairs)
        expect(actual).to eq([
          ids_to_delete.size,
          phone_numbers_with_all_leads_deleted
        ])
      end
    end

    context 'one or more households have no leads remaining' do
      let(:ids_to_delete) do
        stop = 0
        households.keys[0..3].each do |phone|
          stop += households[phone][:leads].size
        end
        stop -= 1
        all_ids[0..stop]
      end
      it 'returns [removed_lead_count, [phone_numbers_of_empty_households]]' do
        expect(subject.delete_leads(key_id_pairs)).to eq([
          ids_to_delete.size,
          households.keys[0..3]
        ])
      end
    end

    context 'stats' do
      it 'decrements campaign total_leads' do
        starting_total_leads = campaign.call_list.stats['total_leads']
        expect(starting_total_leads).to eq leads_count
        subject.delete_leads(key_id_pairs)
        ending_total_leads = campaign.call_list.stats['total_leads']
        expect(ending_total_leads).to eq starting_total_leads - ids_to_delete.size
      end
      it 'increments list removed_leads' do
        subject.delete_leads(key_id_pairs)
        expect(prune_voter_list.stats['removed_leads']).to eq ids_to_delete.size
      end
      it 'increments list total_leads' do
        subject.delete_leads(key_id_pairs)
        expect(prune_voter_list.stats['total_leads']).to eq ids_to_delete.size
      end
    end
    context 'no household found for given lead' do
      it 'returns [0, []]' do
        campaign.dial_queue.purge
        expect(subject.delete_leads(key_id_pairs)).to eq([0, []])
      end
    end
  end
end

