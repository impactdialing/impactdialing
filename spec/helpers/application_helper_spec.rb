require 'rails_helper'

shared_examples 'collection and dependency issue' do
  context 'when the collection is empty' do
    context 'and when the collection dependency is empty' do
      it 'displays the alert message to add the dependency' do
        expect(
          helper.missing_data_text(collection, dependency, options)
        ).to include 'In order to add a new'
        expect(
          helper.missing_data_text(collection, dependency, options)
        ).to_not include 'No #collection# entered'
      end
    end

    context 'when the collection dependency is not empty' do
      let(:collection) { 0 }
      let(:dependency) { 1 }

      it 'displays "no #collection# entered"' do
        expect(
          helper.missing_data_text(collection, dependency, options)
        ).to include 'entered'
        expect(
          helper.missing_data_text(collection, dependency, options)
        ).to_not include 'In order to add a new'
      end
    end
  end

  context 'when the collection is not empty' do
    let(:collection) { 1 }
    let(:dependency) { 1 }
    let(:content) { "I AM BLOCK OF CODE" }

    it 'displays neither "no #collection# entered" nor the alert message' do
      expect(
        helper.missing_data_text(collection, dependency, options) do
          content
        end
      ).to eq content
    end
  end
end

describe ApplicationHelper do
  describe '#standard_env_name' do
    context 'Rails.env =~ /(development|test)/' do
      it 'returns Rails.env' do
        expect(helper.standard_env_name).to eq 'test'
        allow(helper).to receive(:rails_env){ 'development' }
        expect(helper.standard_env_name).to eq 'development'
      end
    end

    context 'Rails.env == "heroku"' do
      it 'returns "production"' do
        allow(helper).to receive(:rails_env){ 'heroku' }
        expect(helper.standard_env_name).to eq 'production'
      end
    end
    context 'Rails.env == "heroku_staging"' do
      it 'returns "staging"' do
        allow(helper).to receive(:rails_env){ 'heroku_staging' }
        expect(helper.standard_env_name).to eq 'staging'
      end
    end
  end
  describe '#missing_data_text' do
    let(:collection) { 0 }
    let(:dependency) { 0 }

    describe 'when collection is campaigns & dependency is scripts' do
      let(:options) {{ collection_type: 'campaign', dependency_type: 'script' }}

      it_behaves_like 'collection and dependency issue'
    end

    describe 'when collection is callers & dependency is campaigns' do
      let(:options) {{ collection_type: 'caller', dependency_type: 'campaign' }}

      it_behaves_like 'collection and dependency issue'
    end
  end
end
