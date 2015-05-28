require 'spec_helper'

describe 'FccCompliance' do
  subject{ FccCompliance }

  describe '#abandon_rate(answer_count, abandon_count)' do
    it 'returns abandon_count / (answer_count + abandon_count)' do
      abandon_count = 5
      answer_count  = 10
      expect(subject.abandon_rate(answer_count, abandon_count)).to eq(5.0 / 15)
    end

    it 'returns zero when dividing by zero' do
      expect(subject.abandon_rate(0,0)).to eq 0
    end
  end
end
