
require_relative '../../lib/faexport'
require_relative 'check_helper'

require 'rspec'

describe 'FA watchlist parser' do

  before do
    config = File.exist?('settings-test.yml') ? YAML.load_file('settings-test.yml') : {}
    @app = FAExport::Application.new(config).instance_variable_get(:@instance)
    @fa = @app.instance_variable_get(:@fa)
    @fa.login_cookie = COOKIE_DEFAULT
  end

  after do
    # Do nothing
  end

  [true, false].each do |is_watchers|
    it 'displays a valid list of profile names' do
      list = @fa.budlist(TEST_USER, 1, is_watchers)
      expect(list).to be_instance_of Array
      expect(list).not_to be_empty
      list.each do |bud|
        expect(bud).to be_instance_of String
        expect(bud).not_to be_blank
      end
    end

    it 'fails when given a non-existent profile' do
      expect { @fa.budlist(TEST_USER_NOT_EXIST, 1, is_watchers) }.to raise_error(FASystemError)
    end

    it 'handles an empty watchers list' do
      bud_list = @fa.budlist(TEST_USER_NO_WATCHERS, 1, is_watchers)
      expect(bud_list).to be_instance_of Array
      expect(bud_list).to be_empty
    end
  end

  it 'displays a different list for is watching vs watched by' do
    expect(@fa.budlist(TEST_USER, 1, true)).not_to eql(@fa.budlist(TEST_USER, 1, false))
  end

  it 'returns 200 users when more than one page exists' do
    bud_list = @fa.budlist(TEST_USER_OVER_200_WATCHERS, 1, true)
    expect(bud_list).to be_instance_of Array
    expect(bud_list.length).to eql(200)
    bud_list.each do |bud|
      expect(bud).to be_instance_of String
      expect(bud).not_to be_blank
    end
  end

  it 'displays a second page, different than the first' do
    bud_list1 = @fa.budlist(TEST_USER_OVER_200_WATCHERS, 1, true)
    bud_list2 = @fa.budlist(TEST_USER_OVER_200_WATCHERS, 2, true)
    expect(bud_list1).to be_instance_of Array
    expect(bud_list1.length).to eql(200)
    expect(bud_list2).to be_instance_of Array
    expect(bud_list1).not_to eql(bud_list2)
  end
end
