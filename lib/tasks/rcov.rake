if Rails.env == "test"
  require 'rake'
  require 'rspec'
  require 'rspec/core/rake_task'

  RcovOpts = %w{--rails --text-summary --text-counts }

  namespace :spec do
    namespace :rcov do
      def coverage_path_for(name)
        target_dir = "coverage_#{name}"
        ENV['CC_BUILD_ARTIFACTS'] ? File.join(ENV['CC_BUILD_ARTIFACTS'], target_dir) : target_dir
      end

      desc  "Run controller specs with rcov"
      RSpec::Core::RakeTask.new(:controller => 'db:test:prepare') do |t|
        t.pattern = 'spec/controllers/**/*_spec.rb'
        t.rcov = true
        t.rcov_opts = RcovOpts.clone      
        t.rcov_opts << "--exclude osx\/objc,gems\/,spec\/,features\/"
        t.rcov_opts << "--output #{coverage_path_for('controller')}"
      end

      desc "Run only the unit specs with rcov"
      RSpec::Core::RakeTask.new(:unit => 'db:test:prepare') do |t|
        t.pattern = 'spec/models/**/*_spec.rb', 'spec/helpers/**/*_spec.rb'
        t.rcov = true
        t.rcov_opts = RcovOpts.clone
        t.rcov_opts << "--exclude osx\/objc,gems\/,spec\/,features\/,app\/controllers\/"
        t.rcov_opts << "--output #{coverage_path_for('unit')}"
      end    
    end
  end
end
