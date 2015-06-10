module ImpactPlatform
  module Metrics
    def self.active?
      (not Rails.env.test?)
    end
    def self.print(str)
      STDOUT.puts(str) if self.active?
    end
    def self.count(metric_name, number, source=nil)
      strs = [
        "count##{metric_name}=#{number}"
      ]
      if source.present?
        strs.unshift "source=#{source}"
      end
      print(strs.join(' '))
    end

    def self.measure(measure_name, sec, source=nil)
      strs = [
        "measure##{measure_name}=#{(sec*1000).to_i}mS"
      ]
      if source.present?
        strs.unshift "source=#{source}"
      end
      print(strs.join(' '))
    end

    def self.sample(sample_name, value, source=nil)
      strs = [
        "sample##{sample_name}=#{value}"
      ]
      if source.present?
        strs.unshift "source=#{source}"
      end
      print(strs.join(' '))
    end

    class Benchmark
      attr_reader :metric_prefix

      def initialize(metric_prefix)
        @metric_prefix = metric_prefix
      end

      def time(name, &block)
        start  = Time.now.to_i
        result = yield
        stop   = Time.now.to_i
        diff   = ((stop - start) * 1000).to_i

        ImpactPlatform::Metrics.print("measure##{metric_prefix}.#{name}=#{diff}ms")

        result
      end
    end

    class Autoscale
      attr_reader :process

    private
      def count(name, number)
        ImpactPlatform::Metrics.count("#{self.class.to_s.underscore.split('/').last}.#{process}.#{name}", number)
      end

    public
      def initialize(process)
        @process = process
      end

      def total
        count('total', 1)
      end

      def up
        count('up', 1)
      end

      def down
        count('down', 1)
      end

      def error
        count('error', 1)
      end
    end

    class JobStatus
      attr_reader :process, :source

    private
      def count(name, number)
        ImpactPlatform::Metrics.count("#{self.class.to_s.underscore.split('/').last}.#{process}.#{name}", number, source)
      end

    public
      def self.completed(process, source=nil)
        self.new(process, source).completed
      end

      def self.started(process, source=nil)
        self.new(process, source).started
      end

      def self.error(process, source=nil)
        self.new(process, source).error
      end

      def self.sigterm(process)
        self.new(process).sigterm
      end

      def initialize(process, source=nil)
        @process = process
        @source  = source
      end

      def completed
        count('completed', 1)
        self
      end

      def error
        count('error', 1)
        self
      end

      def started
        count('started', 1)
        self
      end

      def sigterm
        count('sigterm', 1)
        self
      end
    end
  end
end
