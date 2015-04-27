require 'rails_helper'

describe CampaignHelper do
  describe '#missing_data_text' do
    context 'when the collection is empty' do
      context 'and when the collection dependency is empty' do
        let(:collection) { [] }
        let(:dependency) { [] }
        let(:options) {{ collection_type: 'campaign', dependency_type: 'script' }}

        it 'displays the alert message to add the dependency' do
          expect(helper.missing_data_text(collection, dependency, options)).to include 'In order to add a new'
          expect(helper.missing_data_text(collection, dependency, options)).to_not include 'No #collection# entered'
        end
      end

      context 'when the collection dependency is not empty' do
        let(:collection) { [] }
        let(:dependency) { ["dependency"] }
        let(:options) {{ collection_type: 'campaign', dependency_type: 'script' }}

        it 'displays "no #collection# entered"' do
          expect(helper.missing_data_text(collection, dependency, options)).to include 'entered'
          expect(helper.missing_data_text(collection, dependency, options)).to_not include 'In order to add a new'
        end
      end
    end

    context 'when the collection is not empty' do
      let(:collection) { ["collection"] }
      let(:dependency) { ["dependency"] }
      let(:options) {{ collection_type: 'campaign', dependency_type: 'script' }}
      let(:block) { "I AM BLOCK OF CODE" }

      it 'displays neither "no #collection# entered" nor the alert message' do
        expect(helper.missing_data_text(collection, dependency, options) do block end).to_not include 'In order to add a new'
        expect(helper.missing_data_text(collection, dependency, options) do block end).to_not include 'entered'
      end
    end
  end
end
