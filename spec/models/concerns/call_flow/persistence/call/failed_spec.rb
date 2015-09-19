 require 'rails_helper'

 describe 'CallFlow::Persistence::Call::Failed' do
   include ListHelpers

   shared_examples_for 'first or subsequent call persistence' do
     it 'creates CallAttempt record w/ status of Failed' do
       expect{ subject.persist_call_outcome }.to change { CallAttempt.count }.by 1
     end

     it 'removes the presented household copy' do
       subject.persist_call_outcome
       expect(subject.leads.send(:presented_households).find(phone)).to be_empty
     end
   end

   let(:campaign){ create(:power) }
   let(:voter_list){ create(:voter_list, campaign: campaign) }
   let(:households){ build_household_hashes(5, voter_list) }
   let(:phone){ households.keys.first }

   before do
     import_list(voter_list, households, 'active', 'presented')
     campaign.dial_queue.households.find_presentable(phone)
     CallFlow::Call::Failed.create(campaign, phone, {})
   end
   subject{ CallFlow::Persistence::Call::Failed.new(campaign.id, phone) }

   context 'First dial to household fails' do
     it_behaves_like 'first or subsequent call persistence'

     it 'creates Household record w/ status of Failed' do
       expect{ subject.persist_call_outcome }.to change{ Household.count }.by 1
     end

     it 'creates Voter record(s) w/ status of Failed' do
       expect{ subject.persist_call_outcome }.to change{ Voter.count }.by households[phone][:leads].size
     end
   end

   context 'Subsequent dials to household fails' do
     let(:household){ campaign.households.where(phone: phone).first }

     before do
       hh = campaign.households.create(phone: phone, status: CallAttempt::Status::SUCCESS)
     end

     it_behaves_like 'first or subsequent call persistence'

     it 'updates Household record w/ status of Failed' do
       subject.persist_call_outcome
       expect(household.status).to eq CallAttempt::Status::FAILED
     end
   end
 end

