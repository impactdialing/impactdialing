require 'spec_helper'
require 'impact_platform/metrics'

describe ImpactPlatform::Metrics do
  describe '.count(metric_name, number)' do
    it 'prints Librato count metrics' do
      metric_name = 'blah.diggity'
      number      = 1
      expected    = "count##{metric_name}=#{number}"
      expect(STDOUT).to receive(:puts).with(expected)

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
      expect(ImpactPlatform::Metrics).to receive(:count).with("autoscale.#{process}.total", number)
      subject.total
    end
  end

  describe '#up' do
    it "counts #{prefix}.{process}.up=1" do
      expect(ImpactPlatform::Metrics).to receive(:count).with("autoscale.#{process}.up", number)
      subject.up
    end
  end

  describe '#down' do
    it "counts #{prefix}.{process}.down=1" do
      expect(ImpactPlatform::Metrics).to receive(:count).with("autoscale.#{process}.down", number)
      subject.down
    end
  end

  describe '#error' do
    it "counts #{prefix}.{process}.error=1" do
      expect(ImpactPlatform::Metrics).to receive(:count).with("autoscale.#{process}.error", number)
      subject.error
    end
  end
end

describe ImpactPlatform::Metrics::JobStatus do
  let(:process){ 'my_job_class' }
  subject{ ImpactPlatform::Metrics::JobStatus }

  describe '.error(process)' do
    it 'prints error count' do
      expected = "count#job_status.#{process}.error=1"
      expect(STDOUT).to receive(:puts).with(expected)
      subject.error(process)
    end
  end
  describe '.sigterm(process)' do
    it 'prints sigterm count' do
      expected = "count#job_status.#{process}.sigterm=1"
      expect(STDOUT).to receive(:puts).with(expected)
      subject.sigterm(process)
    end
  end
  describe '.completed(process)' do
    it 'prints completed count' do
      expected = "count#job_status.#{process}.completed=1"
      expect(STDOUT).to receive(:puts).with(expected)
      subject.completed(process)
    end
  end
  describe '.started(process)' do
    it 'prints started count' do
      expected = "count#job_status.#{process}.started=1"
      expect(STDOUT).to receive(:puts).with(expected)
      subject.started(process)
    end
  end
end
