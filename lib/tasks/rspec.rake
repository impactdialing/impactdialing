require "rspec/core/rake_task"
namespace :spec do
  desc 'Run all specs in spec directory (exluding features specs)'
    RSpec::Core::RakeTask.new(:nofeature) do |task|
    file_list = FileList['spec/**/*_spec.rb']
    %w(features).each do |exclude|
      file_list = file_list.exclude("spec/#{exclude}/**/*_spec.rb")
    end

    task.pattern = file_list
  end

  desc 'Run all specs in spec directory features directory'
    RSpec::Core::RakeTask.new(:integration) do |task|
    file_list = FileList['spec/features/*_spec.rb']
    task.pattern = file_list
  end

end