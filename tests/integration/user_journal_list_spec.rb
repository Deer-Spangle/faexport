
require './lib/faexport'
require_relative 'check_helper'

require 'rspec'

describe 'FA journal list parser' do

  before do
    config = File.exist?('settings-test.yml') ? YAML.load_file('settings-test.yml') : {}
    @app = FAExport::Application.new(config).instance_variable_get(:@instance)
    @fa = @app.instance_variable_get(:@fa)
    @fa.login_cookie = COOKIE_DEFAULT
  end

  after do
    # Do nothing
  end

  it 'returns a list of journal IDs' do
    journals = @fa.journals(TEST_USER, 1)
    expect(journals).to be_instance_of Array
    expect(journals).not_to be_empty
    journals.each do |journal|
      expect(journal[:id]).to match(/^[0-9]+$/)
      expect(journal[:title]).not_to be_blank
      expect(journal[:description]).not_to be_blank
      expect(journal[:link]).to eql("https://www.furaffinity.net/journal/#{journal[:id]}/")
      expect(journal[:posted]).to be_valid_date_and_match_iso(journal[:posted_at])
    end
  end

  it 'fails when given a non-existent user' do
    expect { @fa.journals(TEST_USER_NOT_EXIST, 1) }.to raise_error(FASystemError)
  end

  it 'handles an empty journal listing' do
    journals = @fa.journals(TEST_USER_NO_JOURNALS, 1)
    expect(journals).to be_instance_of Array
    expect(journals).to be_empty
  end

  it 'displays a second page, different than the first' do
    journals1 = @fa.journals(TEST_USER_OVER_25_JOURNALS, 1)
    journals2 = @fa.journals(TEST_USER_OVER_25_JOURNALS, 2)
    expect(journals1).to be_instance_of Array
    expect(journals1).not_to be_empty
    expect(journals1.length).to be 25
    expect(journals2).to be_instance_of Array
    expect(journals2).not_to be_empty
    expect(journals1).not_to eql(journals2)
  end
end
