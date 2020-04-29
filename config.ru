$LOAD_PATH << File.dirname(__FILE__)

require 'lib/faexport'

config = File.exist?('settings.yml') ? YAML.load_file('settings.yml') : {}
use FAExport::Application, config
run Sinatra::Application

log_file = ENV['LOG_FILE'] || "logs/faexport.log"
FileUtils.mkdir_p(File.dirname(log_file))

class TeeIO < IO
  def initialize(orig, file)
    @orig = orig
    @file = file
  end

  def write(string)
    @file.write string
    @orig.write string
  end
end

log = File.new(log_file, "a+")
log.sync = true
$stdout = TeeIO.new($stdout, log)
$stderr = TeeIO.new($stderr, log)
