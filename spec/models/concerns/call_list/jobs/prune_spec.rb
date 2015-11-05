require 'rails_helper'

describe CallList::Jobs::Prune do
  let(:subject){ CallList::Jobs::Prune }
  let(:voter_list){ create(:voter_list) }
  let(:email){ Forgery(:email).address }

  describe '.perform(id, scope)' do
    context 'scope = "numbers"' do
      let(:data) do
        (1..5).map{ Forgery(:address).phone }
      end
      let(:mailer) do
        instance_double(VoterListMailer, {
          pruned_numbers: nil
        })
      end
      let(:pruner) do
        instance_double(CallList::Prune::Numbers, {
          parse: nil,
          delete: nil,
          cursor: 0,
          results: {},
          final_results: {}
        })
      end
      let(:scope){ 'numbers' }

      before do
        allow(VoterListMailer).to receive(:new){ mailer }
        allow(CallList::Prune::Numbers).to receive(:new){ pruner }
        allow(pruner).to receive(:parse).and_yield(data)
      end

      it 'instantiate CallList::Prune::Numbers' do
        expect(CallList::Prune::Numbers).to receive(:new).
          with(voter_list, 0, nil){
            pruner
          }
        subject.perform(voter_list.id, scope, email)
      end
      it '#parse numbers from the file' do
        expect(pruner).to receive(:parse)
        subject.perform(voter_list.id, scope, email)
      end
      it '#delete numbers yielded from #parse' do
        expect(pruner).to receive(:delete).with(data)
        subject.perform(voter_list.id, scope, email)
      end
      it 'tells the #mailer to send #pruned_numbers message' do
        expect(mailer).to receive(:pruned_numbers).with(pruner.final_results)
        expect(subject).to receive(:mailer){ mailer }
        subject.perform(voter_list.id, scope, email)
      end
    end
  end
end
