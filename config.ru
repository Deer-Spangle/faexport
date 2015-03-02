$LOAD_PATH << File.dirname(__FILE__)

require 'lib/faexport'

config = if File.exist?('settings.yml')
           YAML.load_file('settings.yml')
         else
           { 'username' => ENV['FA_USERNAME'], 'password' => ENV['FA_PASSWORD'] }
         end

use FAExport::Application, config
run Sinatra::Application
