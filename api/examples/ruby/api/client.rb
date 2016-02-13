require 'uri'

class ImpactDialing::Api::Client
  class InvalidCampaign < ArgumentError; end

  module REST
    include ImpactDialing::Api::Config

    def http
      @http ||= Faraday.new(host) do |conn|
        conn.request :impactdialing_auth
        conn.request :multipart
        conn.request :url_encoded

        conn.adapter Faraday.default_adapter
      end
    end

    def host
      "#{scheme}://#{api_host}/"
    end

    def debug_response(response)
      print "Response (#{response.status}):\n"
      print "URL: #{response.env.url}\n"
      print "=== Body ===\n"
      print response.body
      print "\n=== Body ===\n"
    end

    def parse_json(text)
      OpenStruct.new JSON.parse text
    end
  end

  def scripts
    @scripts ||= Scripts.new
  end

  def campaigns
    @campaigns ||= Campaigns.new
  end

  require_relative 'client/resource'
  require_relative 'client/collection'
  require_relative 'client/campaign'
  require_relative 'client/scripts'
  require_relative 'client/campaigns'
  require_relative 'client/voter_lists'
end
