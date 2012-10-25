
puts "sfSDF"

namespace :bundle do
  task :install, :except => { :no_release => true } do
    #run "bundle install --gemfile #{current_path}/Gemfile --path #{shared_path}/bundle #{fetch(:bundle_flags,'')}"
    
    bundle_cmd     = fetch(:bundle_cmd, "bundle")
    bundle_flags   = fetch(:bundle_flags, "--deployment --quiet")
    bundle_dir     = fetch(:bundle_dir, File.join(fetch(:shared_path), 'bundle'))
    bundle_gemfile = fetch(:bundle_gemfile, "Gemfile")
    bundle_without = [*fetch(:bundle_without, [:development, :test])].compact

    args = ["--gemfile #{File.join(fetch(:release_path), bundle_gemfile)}"]
    args << "--path #{bundle_dir}" unless bundle_dir.to_s.empty?
    args << bundle_flags.to_s
    args << "--without #{bundle_without.join(" ")}" unless bundle_without.empty?

    run "cd #{fetch(:release_path)} && #{bundle_cmd} install #{args.join(' ')}"
  end
end
