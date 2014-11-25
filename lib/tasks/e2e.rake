begin
  require 'rspec/core/rake_task'

  desc "Run all :admin tagged specs in spec/features directory"
  RSpec::Core::RakeTask.new("spec:e2e:admin") do |t, task_args|
    ENV['RAILS_ENV'] = 'e2e'
    t.pattern        = "features/**/*_spec.rb"
    t.rspec_opts     = "--tag admin --tag ~js"
  end

  desc "Run all :caller_ui tagged specs in spec/features directory"
  RSpec::Core::RakeTask.new("spec:e2e:caller") do |t, task_args|
    ENV['RAILS_ENV'] = 'e2e'
    t.pattern        = "features/**/*_spec.rb"
    t.rspec_opts     = "--tag caller_ui"
  end

  desc "Run all :js tagged specs in spec/features directory"
  RSpec::Core::RakeTask.new("spec:e2e:js") do |t, task_args|
    ENV['RAILS_ENV'] = 'e2e'
    t.pattern        = "features/**/*_spec.rb"
    t.rspec_opts     = "--tag js"
  end

  desc "Run all data heavy specs"
  RSpec::Core::RakeTask.new("spec:data_heavy") do |t, task_args|
    ENV['RAILS_ENV'] = 'test'
    t.pattern        = "spec/**/*_spec.rb"
    t.rspec_opts     = "--tag data_heavy"
  end

  desc "Run all specs in spec directory except /features"
  RSpec::Core::RakeTask.new("spec:note2e") do |t, task_args|
    ENV['RAILS_ENV'] = 'test'
    file_list        = FileList['spec/**/*_spec.rb']

    %w(features).each do |exclude|
      file_list = file_list.exclude("spec/#{exclude}/**/*_spec.rb")
    end
    t.pattern    = file_list
    t.rspec_opts = "--tag ~data_heavy"
  end
rescue LoadError
end