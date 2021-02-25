# frozen_string_literal: true

$LOAD_PATH << File.dirname(__FILE__)

require 'lib/faexport'

config = File.exist?('settings.yml') ? YAML.load_file('settings.yml') : {}
use FAExport::Application, config
run Sinatra::Application
