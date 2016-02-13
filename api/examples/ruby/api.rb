module ImpactDialing::Api
  module Config
    def api_key
      ENV['IMPACTDIALING_API_KEY']
    end

    def api_host
      ENV['IMPACTDIALING_API_HOST']
    end

    def scheme
      api_host =~ /(localhost|127\.0\.0\.1)/ ? 'http' : 'https'
    end
  end
  extend Config

  module FaradayApiKeyMiddleware
    class ApiAuthentication < Faraday::Middleware
      def call(request_env)
        # todo: better query str updating
        url = request_env[:url]
        if url.query.nil?
          url.query = "api_key=#{ImpactDialing::Api.api_key}"
        else
          url.query = "#{url.query}&api_key=#{ImpactDialing::Api.api_key}"
        end
        request_env[:url] = url

        @app.call(request_env)
      end
    end

    if Faraday::Middleware.respond_to? :register_middleware
      Faraday::Request.register_middleware({
        impactdialing_auth: lambda { ApiAuthentication }
      })
    end
  end

  require_relative 'api/client'
end
