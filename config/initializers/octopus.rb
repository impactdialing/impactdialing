Octopus.setup do |config|
  parsed_config  = ERB.new(File.read(File.join(File.dirname(__FILE__), '..', 'shards.yml'))).result
  octopus_config = YAML.load(parsed_config)['octopus']
  
  if octopus_config['environments'] != ['none']
    config.environments = octopus_config['environments']
    config.shards       = octopus_config[ENV['RAILS_ENV']]
  end
end
