class ImpactDialing::Api::Client::Scripts
  include ImpactDialing::Api::Client::Collection

  def path
    "/client/scripts.json"
  end

  def parse_json(text)
    JSON.parse(text).map do |item|
      OpenStruct.new item
    end
  end
end
