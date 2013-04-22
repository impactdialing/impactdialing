module Features
  module DialinHelpers
    HOST_NAME = "http://localhost:3010"
    def dial_in
      conn = Faraday.new(:url => HOST_NAME) do |faraday|
        faraday.request  :url_encoded
        faraday.adapter  Faraday.default_adapter
      end
      conn.post '/DialIn.json', {}
    end

    def enter_pin

    end
  end
end