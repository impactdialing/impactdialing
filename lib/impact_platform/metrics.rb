module ImpactPlatform
  module Metrics
    def self.count(metric_name, number)
      STDOUT.puts("count##{metric_name}=#{number}")
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
      attr_reader :process

    private
      def count(name, number)
        ImpactPlatform::Metrics.count("#{self.class.to_s.underscore.split('/').last}.#{process}.#{name}", number)
      end

    public
      def self.completed(process)
        self.new(process).completed
      end

      def self.started(process)
        self.new(process).started
      end

      def self.error(process)
        self.new(process).error
      end

      def self.sigterm(process)
        self.new(process).sigterm
      end

      def initialize(process)
        @process = process
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
