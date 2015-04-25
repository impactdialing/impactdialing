require 'rails_helper'

describe CampaignHelper do
  describe '#missing_data_text' do
    context 'when the collection is empty' do
      context 'when the collection dependency is empty' do
        let(:collection) { [] }
        let(:dependency) { [] }

        it 'displays the alert message to add the dependency' do
          expect(helper.missing_data_text(collection, dependency)).to include 'In order to add a new'
          expect(helper.missing_data_text(collection, dependency)).to_not include 'No #collection# entered'
        end
      end

      context 'when the collection dependency is not empty' do
        let(:collection) { [] }
        let(:dependency) { ["dependency"] }

        it 'displays "no #collection# entered"' do
          expect(helper.missing_data_text(collection, dependency)).to include 'entered'
          expect(helper.missing_data_text(collection, dependency)).to_not include 'In order to add a new'
        end
      end
    end

    context 'when the collection is not empty' do
      let(:collection) { ["collection"] }
      let(:dependency) { ["dependency"] }

      it 'displays neither "no #collection# entered" nor the alert message' do
        expect(helper.missing_data_text(collection, dependency)).to_not include 'In order to add a new'
        expect(helper.missing_data_text(collection, dependency)).to_not include 'entered'
      end
    end
  end
end
  # describe '#playground' do
  #   it 'displays paragraphs of content' do
  #     col_1 = ['Hello', 'world', '!']
  #     col_2 = ['Goodbye', 'world', '!']
  #     helper.playground([], col_2) do
  #       puts "Hello & Goodbye"
  #     end
  #     # binding.pry
  #   end
  # end
