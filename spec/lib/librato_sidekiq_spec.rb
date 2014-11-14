require 'spec_helper'

class HandyWorker
  include Sidekiq::Worker
  sidekiq_options queue: :lunch_line
  def self.perform
    p 'build stuff'
  end
end

describe 'LibratoSidekiq' do
  let(:group_name){ '' }
  let(:metric_prefix){ 'heroku.logs' }
  let(:source_namespace){ 'sidekiq' }
  let(:librato_double) do
    double('LibratoDouble', {
      increment: nil,
      timing: nil,
      measure: nil,
      start!: nil
    })
  end

  describe 'naming sources' do
    let(:librato_source){ 'boo' }
    let(:base_source){ [librato_source, source_namespace].join('.') }
    before do
      ENV['LIBRATO_SOURCE'] = librato_source
    end

    it 'includes LIBRATO_SOURCE' do
      expect(LibratoSidekiq.source).to eq base_source
    end

    it 'includes queue name' do
      expect(LibratoSidekiq.source('my_queue')).to eq [base_source, 'my_queue'].join('.')
    end

    it 'includes underscored worker class name' do
      expect(LibratoSidekiq.source('my_queue', HandyWorker.new)).to eq [base_source, 'my_queue', 'handy_worker'].join('.')
    end

    it 'includes extra' do
      source = LibratoSidekiq.source('clogged_queue', HandyWorker.new, 'formatted_extra_context_string')
      expect(source).to eq [base_source, 'clogged_queue', 'handy_worker', 'formatted_extra_context_string'].join('.')
    end

    it 'returns "sidekiq" as only source if ENV["LIBRATO_SOURCE"] is not defined'  do
      ENV['LIBRATO_SOURCE'] = nil
      expect(LibratoSidekiq.source).to eq source_namespace
    end
  end

  describe 'metric operations' do
    let(:name){ 'metric_name' }
    let(:prefixed_name){ "#{metric_prefix}.metric_name" }
    let(:queue_name){ 'funnel' }
    let(:worker_name){ 'handy_worker' }
    let(:source) do
      {source: ['sidekiq', queue_name, worker_name].join('.')}
    end

    before do
      allow(LibratoSidekiq).to receive(:group).and_yield(librato_double)
    end

    it 'increments `name` in group `sidekiq`' do
      expect(librato_double).to receive(:increment).with(prefixed_name, source)

      LibratoSidekiq.increment(name, queue_name, HandyWorker.new)
    end

    it 'timing is named `worker.time` and uses block form' do
      block = Proc.new{ p 'some time consuming operation' }
      expect(librato_double).to receive(:timing).with("#{metric_prefix}.worker.time", source)

      LibratoSidekiq.timing(queue_name, HandyWorker.new) do
        block.call
      end
    end

    describe 'recording statistics' do
      let(:librato_source){ 'app-name' }
      let(:source) do
        {source: [librato_source, source_namespace].join('.')}
      end
      before do
        ENV['LIBRATO_SOURCE'] = librato_source
        HandyWorker.perform_async
      end

      it 'submits total processed' do
        expect(librato_double).to receive(:measure).once.with("#{metric_prefix}.stats.processed", 0, source)
        LibratoSidekiq.record_stats
      end

      it 'submits total failed' do
        expect(librato_double).to receive(:measure).once.with("#{metric_prefix}.stats.failed", 0, source)
        LibratoSidekiq.record_stats
      end

      it 'submits total enqueued' do
        expect(librato_double).to receive(:measure).once.with("#{metric_prefix}.stats.enqueued", 1, source)
        LibratoSidekiq.record_stats
      end

      it 'submits total retry_size' do
        expect(librato_double).to receive(:measure).once.with("#{metric_prefix}.stats.retry_size", 0, source)
        LibratoSidekiq.record_stats
      end

      it 'submits queue.latency for each named queue' do
        expect(librato_double).to receive(:measure).once.with("#{metric_prefix}.queue.latency", anything, {source: [librato_source, source_namespace, 'lunch_line'].join('.')})
        LibratoSidekiq.record_stats
      end

      it 'submits queue.size for each named queue' do
        expect(librato_double).to receive(:measure).once.with("#{metric_prefix}.queue.size", 1, {source: [librato_source, source_namespace, 'lunch_line'].join('.')})
        LibratoSidekiq.record_stats
      end
    end
  end
end
