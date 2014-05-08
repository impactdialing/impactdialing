namespace :callveyor do
  desc "Build release for production, clobbering old release."
  task :build => [:environment] do
    require 'fileutils'

    app_dir     = File.join Rails.root, 'callveyor'
    asset_dir   = File.join Rails.root, 'public', 'callveyor'
    scripts_dir = File.join asset_dir, 'scripts'
    styles_dir  = File.join asset_dir, 'styles'
    view_dir    = File.join Rails.root, 'app', 'views', 'callers', 'station'
    show_view   = [File.join(view_dir, 'show.html.erb')]
    scripts     = Dir.glob File.join scripts_dir, '*.js'
    styles      = Dir.glob File.join styles_dir, '*.css'
    html        = Dir.glob File.join asset_dir, '*.html'

    p "removing #{scripts}"
    FileUtils.rm_f(scripts)
    FileUtils.rmdir(scripts_dir)
    p "removing #{styles}"
    FileUtils.rm_f(styles)
    FileUtils.rmdir(styles_dir)
    p "removing #{html}"
    FileUtils.rm_f(html)
    p "removing #{show_view}"
    FileUtils.rm_f(show_view)

    STDOUT << `cd #{app_dir} && grunt build`

    html = Dir.glob File.join asset_dir, '*.html'
    p "cleaning #{html}"
    FileUtils.rm_f(html)
  end
end
