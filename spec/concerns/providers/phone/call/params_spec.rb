require 'spec_helper'

class ARModel
  # stub for real ActiveRecord Model
end

class Providers::Phone::Call::Params::ARModel
  # stub for expected Param class to generate urls
end

describe Providers::Phone::Call::Params do
  describe '.for(ar_model, type)' do
    let(:ar_model) do
      ARModel.new
    end
    let(:param_inst){ double }
    let(:type){ :default }

    before do
      Providers::Phone::Call::Params::ARModel.stub(:new){ param_inst }
    end

    it 'instantiates a Params::ar_model.class' do
      Providers::Phone::Call::Params::ARModel.should_receive(:new).with(ar_model, type)
      Providers::Phone::Call::Params.for(ar_model, type)
    end

    it 'returns the new instance' do
      actual = Providers::Phone::Call::Params.for(ar_model, type)
      actual.should eq param_inst
    end

    context 'ar_model.class =~ WebuiCallerSession|PhonesOnlyCallerSession' do
      let(:web_session){ create(:webui_caller_session) }
      let(:phone_session){ create(:phones_only_caller_session) }

      after do
        @actual.should be_instance_of Providers::Phone::Call::Params::CallerSession
      end

      it "loads Params::CallerSession when ar_model.class == WebuiCallerSession" do
        @actual = Providers::Phone::Call::Params.for(web_session)
      end

      it "loads Params::CallerSession when ar_model.class == PhonesOnlyCallerSession" do
        @actual = Providers::Phone::Call::Params.for(phone_session)
      end
    end
  end
end