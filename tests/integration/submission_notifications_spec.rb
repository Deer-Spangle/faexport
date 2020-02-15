
require './lib/faexport'
require_relative 'check_helper'

require 'rspec'

describe 'FA submission notifications parser' do

  before do
    config = File.exist?('settings-test.yml') ? YAML.load_file('settings-test.yml') : {}
    @app = FAExport::Application.new(config).instance_variable_get(:@instance)
    @fa = @app.instance_variable_get(:@fa)
    @fa.login_cookie = COOKIE_DEFAULT
  end

  after do
    # Do nothing
  end

  it 'will correctly parse current user' do
    @fa.login_cookie = COOKIE_TEST_USER_2
    new_subs = @fa.new_submissions(nil)
    expect(new_subs[:current_user][:name]).to eql(TEST_USER_2)
    expect(new_subs[:current_user]).to have_valid_profile_link
  end

  it 'should handle zero notifications' do
    @fa.login_cookie = COOKIE_TEST_USER_2
    new_subs = @fa.new_submissions(nil)
    expect(new_subs[:new_submissions]).to be_instance_of Array
    expect(new_subs[:new_submissions]).to be_empty
  end

  it 'should hide nsfw submissions if sfw=1 is specified' do
    @fa.login_cookie = COOKIE_TEST_USER_3
    new_subs = @fa.new_submissions(nil)

    @fa.safe_for_work = true
    new_safe_subs = @fa.new_submissions(nil)

    expect(new_safe_subs[:new_submissions].length).to be < new_subs[:new_submissions].length
  end

  it 'returns a valid list of new submission notifications' do
    @fa.login_cookie = COOKIE_TEST_USER_3
    new_subs = @fa.new_submissions(nil)
    expect(new_subs[:new_submissions]).to be_instance_of Array
    expect(new_subs[:new_submissions]).not_to be_empty
    new_subs[:new_submissions].each do |sub|
      expect(sub).to be_valid_submission
    end
  end

  it 'handles paging correctly' do
    @fa.login_cookie = COOKIE_TEST_USER_3
    all_subs = @fa.new_submissions(nil)[:new_submissions]
    expect(all_subs).to be_instance_of Array
    expect(all_subs).not_to be_empty

    second_sub_id = all_subs[1][:id]
    all_from_second = @fa.new_submissions(second_sub_id)[:new_submissions]
    expect(all_from_second).to be_instance_of Array
    expect(all_from_second).not_to be_empty

    all_after_second = @fa.new_submissions(second_sub_id.to_i-1)[:new_submissions]
    expect(all_after_second).to be_instance_of Array
    expect(all_after_second).not_to be_empty

    expect(all_from_second.length).to be(all_subs.length - 1)
    expect(all_from_second[0][:id]).to eql(all_subs[1][:id])
    expect(all_after_second.length).to be(all_subs.length - 2)
    expect(all_after_second[0][:id]).to eql(all_subs[2][:id])
  end
end