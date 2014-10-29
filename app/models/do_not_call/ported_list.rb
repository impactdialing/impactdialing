require 'uri'

module DoNotCall
  class PortedList
    attr_reader :namespace

    def self.filenames
      @filenames ||= [
        'WIRELESS-TO-WIRELINE-NORANGE.TXT',
        'WIRELINE-TO-WIRELESS-NORANGE.TXT'
      ]
    end

    def self.namespaces
      @namespaces ||= [:landline, :wireless]
    end

    def self.infer_namespace(filename)
      i = filenames.find_index(filename)
      namespaces[i]
    end

    def self.cache(namespace, file)
      list = new(namespace)
      list.cache(file)
      list
    end

    def redis
      @redis ||= Redis.new
    end

    def delete_all
      redis.del key
    end

    def initialize(namespace)
      @namespace = namespace
    end

    def key
      "do_not_call:ported:#{namespace}"
    end

    def cache(file)
      delete_all
      parser = FileParser.new(file)
      parser.in_batches do |ported_numbers|
        redis.sadd key, ported_numbers
      end
    end

    def exists?(phone)
      redis.sismember(key, phone[-10..-1])
    end

    def all
      redis.smembers(key)
    end
  end
end