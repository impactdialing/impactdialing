module ImpactDialing::Api::Client::Collection
  include Forwardable
  include Enumerable
  include ImpactDialing::Api::Client::REST

  delegate :[], to: :_items
  delegate :each, to: :_items
  delegate :empty?, to: :_items

  def path
    raise "Not implemented"
  end

  def parse_json(text)
    json = JSON.parse(text)
    if json.first.kind_of? Hash
      json.map! do |item|
        OpenStruct.new item
      end
    end
    json
  end

  def fetch
    response = http.get(path)

    if response.status == 200
      return parse_json response.body
    end

    debug_response(response)
    return []
  end

  def create(param_scope, scoped_params, unscoped_params={})
    params = {
      param_scope => scoped_params
    }.merge(unscoped_params)
    response = http.post(path, params)

    case response.status
    when 201
      data = parse_json(response.body)
      return after_create(data)
    when 422
      data = parse_json(response.body)

      print "Errors:\n"
      unless data[:errors].nil? or data[:errors].empty?
        data.errors.each do |key,value|
          print "- #{key.gsub('_',' ').capitalize}: #{value}\n"
        end
      else
        print "Raw data: #{data.inspect}\n"
      end
      abort "Fix errors and try again."
    else
      debug_response(response)

      return {}
    end
  end

  def _items
    @_items ||= fetch
  end
end
