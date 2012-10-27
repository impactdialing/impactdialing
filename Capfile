$:.push File.expand_path("../lib", __FILE__)
#
# Load deploy capistrano recipe
#
load 'deploy'

#
# Configure libraries/recipes from Gemfile
#

# https://github.com/stjernstrom/capistrano_colors/README.rdoc
require 'capistrano_colors'

# https://github.com/railsware/capistrano-multiconfig/README.md
require 'capistrano/multiconfig'             

# Load all custom recipes
Dir['recipes/**/*.rb'].each { |recipe| load(recipe) }

# Load main configuration
load 'config/deploy'

# vim syntax=ruby
