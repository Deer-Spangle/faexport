
require './lib/faexport'
require_relative 'check_helper'

require 'rspec'

describe 'FA home page parser' do

  before do
    config = File.exist?('settings-test.yml') ? YAML.load_file('settings-test.yml') : {}
    @app = FAExport::Application.new(config).instance_variable_get(:@instance)
    @fa = @app.instance_variable_get(:@fa)
    @fa.login_cookie = COOKIE_DEFAULT
  end

  after do
    # Do nothing
  end

  it 'has the 4 submission types' do
    home = @fa.home
    expect(home).to have_key(:artwork)
    expect(home).to have_key(:writing)
    expect(home).to have_key(:music)
    expect(home).to have_key(:crafts)
  end

  it 'has valid submissions in all categories' do
    home = @fa.home
    keys = [:artwork, :writing, :music, :crafts]
    home.map do |type, submissions|
      expect(keys).to include(type)
      expect(submissions).not_to be_empty
      submissions.each do |submission|
        expect(submission).to be_valid_submission
      end
    end
  end

  it 'only returns SFW results, if specified' do
    @fa.safe_for_work = true
    home = @fa.home
    home.map do |_, submissions|
      expect(submissions).not_to be_empty
      submissions.map do |submission|
        begin
          full_submission = @fa.submission(submission[:id])
          expect(full_submission[:rating]).to eql("General")
        rescue FASystemError
        end
      end
    end
  end
end