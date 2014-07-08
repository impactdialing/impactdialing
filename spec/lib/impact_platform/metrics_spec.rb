require 'spec_helper'
require 'impact_platform/metrics'

describe ImpactPlatform::Metrics do
  describe '.count(metric_name, number)' do
    it 'prints Librato count metrics' do
      metric_name = 'blah.diggity'
      number      = 1
      expected    = "count##{metric_name}=#{number}"
      STDOUT.should_receive(:puts).with(expected)

      ImpactPlatform::Metrics.count(metric_name, number)
    end
  end
end

describe ImpactPlatform::Metrics::Autoscale do
  prefix = 'autoscale'
  let(:process){ 'my_process' }
  let(:number){ 1 }
  subject{ ImpactPlatform::Metrics::Autoscale.new(process) }

  describe '#total' do
    it "counts #{prefix}.{process}.total=1" do
      ImpactPlatform::Metrics.should_receive(:count).with("autoscale.#{process}.total", number)
      subject.total
    end
  end

  describe '#up' do
    it "counts #{prefix}.{process}.up=1" do
      ImpactPlatform::Metrics.should_receive(:count).with("autoscale.#{process}.up", number)
      subject.up
    end
  end

  describe '#down' do
    it "counts #{prefix}.{process}.down=1" do
      ImpactPlatform::Metrics.should_receive(:count).with("autoscale.#{process}.down", number)
      subject.down
    end
  end

  describe '#error' do
    it "counts #{prefix}.{process}.error=1" do
      ImpactPlatform::Metrics.should_receive(:count).with("autoscale.#{process}.error", number)
      subject.error
    end
  end
end