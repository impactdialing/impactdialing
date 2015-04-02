require 'uri'

module DoNotCall::Jobs
  class CachePortedLists
    extend LibratoResque
    @queue = :general

    def self.url
      ENV['DO_NOT_CALL_PORTED_LISTS_PROVIDER_URL']
    end

    def self.source_filenames
      [
        'WIRELESS-TO-WIRELINE-NORANGE.TXT',
        'WIRELINE-TO-WIRELESS-NORANGE.TXT'
      ]
    end

    def self.perform(s3_root_path)
      source_filenames.each do |filename|
        dest_path = "#{s3_root_path}/#{filename}"
        file      = download(filename).body
        AmazonS3.new.write(dest_path, file)
      end

      Resque.enqueue(DoNotCall::Jobs::RefreshPortedLists)
    end

    # Based on: https://www.tcpacompliance.us/content/tcpa_popup_autoScript.html
    def self.download(filename)
      login_path = '/dnclogin/login.fcc'
      parsed_url = URI.parse(url)
      host       = "#{parsed_url.scheme}://#{parsed_url.host}"
      faraday    = Faraday.new(host) do |builder|
                    # follow redirect after login to download file
                    builder.use FaradayMiddleware::FollowRedirects, limit: 3
                    builder.use :cookie_jar
                    builder.request :url_encoded
                    builder.adapter Faraday.default_adapter
                  end
      # set cookie
      faraday.get(login_path)
      # post auth/n credentials
      response  = faraday.post(login_path, {
        :USER     => parsed_url.user,
        :PASSWORD => parsed_url.password,
        :TARGET => "#{parsed_url.scheme}://#{parsed_url.host}#{parsed_url.path}?file=#{filename}"
      })
    end
  end
end
