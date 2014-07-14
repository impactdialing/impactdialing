require 'impact_platform/metrics'

module ImpactPlatform
  module Heroku
    module UploadDownloadHooks
      def after_enqueue_scale_workers(*args)
        process = 'upload_download'
        rules   = ImpactPlatform::Heroku::Scale::BackgroundScaleRules.new(process)
        scale   = ImpactPlatform::Heroku::Scale.new(process, rules.desired_quantity, Rails.env)
        scale.auto!
      end

      def after_perform_scale_workers(*args)
        process = 'upload_download'
        rules   = ImpactPlatform::Heroku::Scale::BackgroundScaleRules.new(process)
        scale   = ImpactPlatform::Heroku::Scale.new(process, rules.desired_quantity, Rails.env)
        scale.auto!
      end
    end

    class Scale
      attr_reader :process, :desired_quantity, :env

    private
      def heroku_oauth_token_name
        'HEROKU_AUTOSCALE_OAUTH_TOKEN'
      end
      def heroku
        # connect via configured oauth token
        @heroku ||= PlatformAPI.connect_oauth(ENV[heroku_oauth_token_name])
      end

      def metrics
        @metrics ||= ImpactPlatform::Metrics::Autoscale.new(process)
      end

      def envs_available
        {
          'heroku' => 'impactdialing-ps',
          'heroku_staging' => 'impactdialing-staging',
          'test' => 'impactdialing-staging'
        }
      end

    public
      def initialize(process, desired_quantity, env)
        @process          = process
        @desired_quantity = desired_quantity.try(:to_i)
        @env              = env
      end

      def app
        envs_available[env]
      end

      def invalid_quantity?
        (desired_quantity.try(:to_s) || '') !~ /\d+/
      end

      def current_quantity
        @current_quantity ||= heroku.formation.info(app, process)['quantity'].try(:to_i)
      end

      def at_scale?
        current_quantity == desired_quantity
      end

      def scale_up?
        current_quantity < desired_quantity
      end

      def auto!
        # don't make pointless requests
        return false if app.nil? or invalid_quantity?

        begin
          # don't scale if already at the desired quantity
          return false if at_scale?

          metrics.total

          # finally try to scale the process
          heroku.formation.update(app, process, {'quantity' => desired_quantity})

          if scale_up?
            metrics.up
          else
            metrics.down
          end

        rescue Excon::Errors::Error => exception
          metrics.error
          msg = "Heroku PlatformAPI Error"
          UserMailer.new.deliver_exception_notification(msg, exception)
        end

        return true
      end

      class BackgroundScaleRules
        attr_reader :process, :rules

        def default_rules
          [
            {
              quantity: 1, # This many workers
              queue_size: 1 # For this many jobs or more, until the next threshold
            },
            {
              quantity: 2,
              queue_size: 3
            },
            {
              quantity: 3,
              queue_size: 5
            },
            {
              quantity: 5,
              queue_size: 8
            },
            {
              quantity: 8,
              queue_size: 13
            },
            {
              quantity: 13,
              queue_size: 21
            },
            {
              quantity: 21,
              queue_size: 34
            }
          ]
        end

        def initialize(process, rules=[])
          @process = process
          @rules   = rules.empty? ? default_rules : rules
        end

        def desired_quantity
          active_rule[:quantity]
        end

        def active_rule
          return rules.first if queue_size.zero?

          rules.reverse.detect{|rule| queue_size >= rule[:queue_size]}
        end

        def queue_size
          Resque.size(process)
        end
      end
    end
  end
end
