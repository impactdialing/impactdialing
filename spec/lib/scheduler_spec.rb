require 'celluloid_helper'
require 'scheduler'

describe Scheduler do
  include_context 'setup celluloid'

  let(:interval){ 42 }
  subject{ Scheduler.new(interval) }

  describe '.boot!' do
    subject{ Scheduler }

    it 'tells Scheduler::Predictive to run!' do
      expect(Scheduler::Predictive).to receive(:run!)
      subject.boot!
    end
  end

  describe '.new(inteval)' do
    it 'sets :interval to given value' do
      expect(subject.interval).to eq interval
    end
  end

  shared_examples_for 'not implemented' do
    it 'throws Not implemented' do
      expect{ subject.send(target) }.to raise_error RuntimeError
    end
  end
  describe '#run' do
    let(:target){ :run }
    it_behaves_like 'not implemented'
  end

  describe '#process' do
    let(:target){ :process }
    it_behaves_like 'not implemented'
  end
end
