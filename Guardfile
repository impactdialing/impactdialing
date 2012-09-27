guard 'spork', :wait => 50 do
  watch('Gemfile')
  watch('Gemfile.lock')
  watch('config/routes.rb')
  watch('config/application.rb')
  watch('config/environment.rb')
  watch(%r{^config/environments/.+\.rb})
  watch(%r{^config/initializers/.+\.rb})
  watch('spec/spec_helper.rb')
  watch('spec/factories.rb')
end

guard :rspec, :version => 2, :bundler => false, :all_after_pass => false, :all_on_start => false, :keep_failed => false do
  watch('.rspec')                                                            { "spec" }
  watch('spec/spec_helper.rb')                                               { "spec" }
  watch('app/controllers/application_controller.rb')                         { "spec/controllers" }
  watch('config/routes.rb')                                                  { "spec/controllers" }
  watch(%r{^spec/support/(requests|controllers|mailers|models)_helpers\.rb}) { |m| "spec/#{m[1]}" }
  watch(%r{^spec/.+_spec\.rb})

  watch(%r{^app/controllers/(.+)_(controller)\.rb})                          { |m| ["spec/routing/#{m[1]}_routing_spec.rb", "spec/#{m[2]}s/#{m[1]}_#{m[2]}_spec.rb", "spec/requests/#{m[1]}_spec.rb"] }

  watch(%r{^app/(.+)\.rb})                                                   { |m| "spec/#{m[1]}_spec.rb" }
  watch(%r{^lib/(.+)\.rb})                                                   { |m| "spec/lib/#{m[1]}_spec.rb" }
end
