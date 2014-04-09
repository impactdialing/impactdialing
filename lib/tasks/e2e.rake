require 'rspec/core/rake_task'

desc "Run all caller tagged specs in spec/features directory"
RSpec::Core::RakeTask.new("spec:e2e:admin") do |t, task_args|
  ENV['RAILS_ENV'] = 'e2e'
  t.pattern = "features/**/*_spec.rb"
  t.rspec_opts = "--tag caller"
end

desc "Run all admin tagged specs in spec/features directory"
RSpec::Core::RakeTask.new("spec:e2e:caller") do |t, task_args|
  ENV['RAILS_ENV'] = 'e2e'
  t.pattern = "features/**/*_spec.rb"
  t.rspec_opts = "--tag admin"
end

desc "Run all specs in spec directory except /features"
RSpec::Core::RakeTask.new("spec:note2e") do |t, task_args|
  ENV['RAILS_ENV'] = 'test'
  file_list = FileList['spec/**/*_spec.rb']

  %w(features).each do |exclude|
    file_list = file_list.exclude("spec/#{exclude}/**/*_spec.rb")
  end

  t.pattern = file_list
end
