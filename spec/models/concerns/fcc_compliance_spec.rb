require 'spec_helper'

describe 'FccCompliance' do
  subject{ FccCompliance }
  let(:abandon_count){ 5 }
  let(:answer_count){ 10 }

  describe '#abandon_rate(answer_count, abandon_count)' do
    it 'returns abandon_count / (answer_count + abandon_count)' do
      expect(subject.abandon_rate(answer_count, abandon_count)).to eq(5.0 / 15)
    end

    it 'returns zero when dividing by zero' do
      expect(subject.abandon_rate(0,0)).to eq 0
    end
  end

  describe '#abandon_rate_percent(answer_count, abandon_count)' do
    it 'returns a string % rounded up to nearest integer' do
      expect(subject.abandon_rate_percent(answer_count, abandon_count)).to eq('33%')
    end
  end
end
