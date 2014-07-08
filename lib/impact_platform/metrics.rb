module ImpactPlatform
  module Metrics
    def self.count(metric_name, number)
      STDOUT.puts("count##{metric_name}=#{number}")
    end

    class Autoscale
      attr_reader :process

    private
      def count(name, number)
        ImpactPlatform::Metrics.count("autoscale.#{process}.#{name}", number)
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
  end
end
