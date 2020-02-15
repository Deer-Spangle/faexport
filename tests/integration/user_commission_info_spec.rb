
require_relative '../../lib/faexport'
require_relative 'check_helper'

require 'rspec'

describe 'FA commission info parser' do

  before do
    config = File.exist?('settings-test.yml') ? YAML.load_file('settings-test.yml') : {}
    @app = FAExport::Application.new(config).instance_variable_get(:@instance)
    @fa = @app.instance_variable_get(:@fa)
    @fa.login_cookie = COOKIE_DEFAULT
  end

  after do
    # Do nothing
  end

  it 'handles empty commission information' do
    comms = @fa.commissions(TEST_USER)
    expect(comms).to be_instance_of Array
    expect(comms).to be_empty
  end

  it 'displays valid commission information data' do
    comms = @fa.commissions(TEST_USER_2)
    expect(comms).to be_instance_of Array
    expect(comms).not_to be_empty
    comms.each do |comm|
      expect(comm[:title]).not_to be_empty
      expect(comm[:price]).not_to be_empty
      expect(comm[:description]).not_to be_empty
      expect(comm[:submission]).to be_instance_of Hash
      expect(comm[:submission]).to be_valid_submission(true, true)
    end
  end

  it 'fails when given a non-existent user' do
    expect { @fa.shouts(TEST_USER_NOT_EXIST) }.to raise_error(FASystemError)
  end
end
