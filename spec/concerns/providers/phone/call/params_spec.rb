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
  end
end