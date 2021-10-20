# frozen_string_literal: true

$LOAD_PATH << File.dirname(__FILE__)

require "lib/faexport"
require "prometheus/middleware/exporter"

config = File.exist?("settings.yml") ? YAML.load_file("settings.yml") : {}
use FAExport::Application, config
use Prometheus::Middleware::Exporter

run Sinatra::Application
