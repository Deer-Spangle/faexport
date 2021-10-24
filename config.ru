# frozen_string_literal: true

$LOAD_PATH << File.dirname(__FILE__)

require "lib/faexport"
require "prometheus/middleware/exporter"

config = File.exist?("settings.yml") ? YAML.load_file("settings.yml") : {}

rack_app = Rack::Builder.app do
  use FAExport::Application, config

  map "/metrics" do
    unless ENV['PROMETHEUS_PASS'].blank?
      use Rack::Auth::Basic, "Prometheus Metrics" do |username, password|
        Rack::Utils.secure_compare(ENV['PROMETHEUS_PASS'], password)
      end
    end
    use Rack::Deflater
    use Prometheus::Middleware::Exporter, path: ''
    run ->(_) {
      raise Sinatra::NotFound
    }
  end

  run Sinatra::Application
end

run rack_app