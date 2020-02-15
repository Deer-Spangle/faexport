
require './lib/faexport'
require_relative 'check_helper'

require 'rspec'

describe 'FA user profile parser' do

  before do
    config = File.exist?('settings-test.yml') ? YAML.load_file('settings-test.yml') : {}
    @app = FAExport::Application.new(config).instance_variable_get(:@instance)
    @fa = @app.instance_variable_get(:@fa)
    @fa.login_cookie = COOKIE_DEFAULT
  end

  after do
    # Do nothing
  end

  context 'when getting user profile' do
    it 'gives valid basic profile information' do
      profile = @fa.user(TEST_USER)
      # Check initial values
      expect(profile[:id]).to be_nil
      expect(profile[:name]).to eql(TEST_USER)
      expect(profile[:profile]).to eql("https://www.furaffinity.net/user/#{TEST_USER}/")
      expect(profile[:account_type]).to eql("Member")
      expect(profile[:avatar]).to be_valid_avatar_for_user(TEST_USER)
      expect(profile[:full_name]).not_to be_blank
      expect(profile[:artist_type]).not_to be_blank
      expect(profile[:user_title]).not_to be_blank
      expect(profile[:user_title]).to eql(profile[:artist_type])
      expect(profile[:current_mood]).to eql("accomplished")
      # Check registration date
      expect(profile[:registered_since]).to be_valid_date_and_match_iso(profile[:registered_at])
      # Check description
      expect(profile[:artist_profile]).not_to be_blank
      # Check numeric values
      [:pageviews, :submissions, :comments_received, :comments_given, :journals, :favorites].each do |key|
        expect(profile[key]).not_to be_blank
        expect(profile[key]).to match(/^[0-9]+$/)
      end
    end

    it 'fails when given a non-existent profile' do
      expect { @fa.user(TEST_USER_NOT_EXIST) }.to raise_error(FASystemError)
    end

    it 'handles square brackets in profile name' do
      profile_with_brackets = "l[i]s"
      profile = @fa.user(profile_with_brackets)
      expect(profile[:name].downcase).to eql(profile_with_brackets)
    end

    it 'shows featured submission' do
      profile = @fa.user(TEST_USER_2)
      expect(profile[:featured_submission]).not_to be_nil
      expect(profile[:featured_submission]).to be_valid_submission(true)
    end

    it 'handles featured submission not being set' do
      profile = @fa.user(TEST_USER)
      expect(profile[:featured_submission]).to be_nil
    end

    it 'shows profile id' do
      profile = @fa.user(TEST_USER_2)
      expect(profile[:profile_id]).not_to be_nil
      expect(profile[:profile_id]).to be_valid_submission(true, true)
    end

    it 'handles profile id not being set' do
      profile = @fa.user(TEST_USER)
      expect(profile[:profile_id]).to be_nil
    end

    it 'shows artist information' do
      profile = @fa.user(TEST_USER_2)
      expect(profile[:artist_information]).to be_instance_of Hash
      expect(profile[:artist_information]).to have_key(:"Age")
      expect(profile[:artist_information][:"Age"]).to eql("70")
      expect(profile[:artist_information]).to have_key(:"Species")
      expect(profile[:artist_information][:"Species"]).to eql("Robot")
      expect(profile[:artist_information]).to have_key(:"Shell of Choice")
      expect(profile[:artist_information][:"Shell of Choice"]).to eql("irb")
      expect(profile[:artist_information]).to have_key(:"Favorite Website")
      expect(profile[:artist_information][:"Favorite Website"]).to start_with("<a href=")
      expect(profile[:artist_information][:"Favorite Website"]).to include("https://www.ruby-lang.org")
      expect(profile[:artist_information][:"Favorite Website"]).to end_with("</a>")
      expect(profile[:artist_information]).not_to have_key(":Personal quote")
    end

    it 'handles blank artist information box' do
      profile = @fa.user(TEST_USER)
      expect(profile[:artist_information]).to be_instance_of Hash
      expect(profile[:artist_information]).to be_empty
    end

    it 'shows contact information' do
      profile = @fa.user(TEST_USER_2)
      expect(profile[:contact_information]).to be_instance_of Array
      expect(profile[:contact_information]).not_to be_empty
      profile[:contact_information].each do |item|
        expect(item[:title]).not_to be_blank
        expect(item[:name]).not_to be_blank
        expect(item).to have_key(:link)
      end
    end

    it 'handles no contact information being set' do
      profile = @fa.user(TEST_USER)
      expect(profile[:profile_id]).to be_nil
    end

    it 'lists watchers of specified account' do
      profile = @fa.user(TEST_USER)
      expect(profile[:watchers]).to be_instance_of Hash
      expect(profile[:watchers][:count]).to be_instance_of Integer
      expect(profile[:watchers][:count]).to be > 0
      expect(profile[:watchers][:recent]).to be_instance_of Array
      expect(profile[:watchers][:recent].length).to be <= profile[:watchers][:count]
      profile[:watchers][:recent].each do |item|
        expect(item).to have_valid_profile_link(true)
      end
      list = profile[:watchers][:recent].map do |item|
        item[:profile_name]
      end
      expect(list).to include(TEST_USER_2)
    end

    it 'lists accounts watched by specified account' do
      profile = @fa.user(TEST_USER)
      expect(profile[:watching]).to be_instance_of Hash
      expect(profile[:watching][:count]).to be_instance_of Integer
      expect(profile[:watching][:count]).to be > 0
      expect(profile[:watching][:recent]).to be_instance_of Array
      expect(profile[:watching][:recent].length).to be <= profile[:watching][:count]
      profile[:watching][:recent].each do |item|
        expect(item).to have_valid_profile_link(true)
      end
    end
  end

  context 'when listing a user\'s shouts' do
    it 'displays a valid list of shouts' do
      shouts = @fa.shouts(TEST_USER)
      expect(shouts).to be_instance_of Array
      shouts.each do |shout|
        expect(shout[:id]).to match(/^shout-[0-9]+$/)
        expect(shout).to have_valid_profile_link
        expect(shout[:avatar]).to be_valid_avatar_for_user(shout[:profile_name])
        expect(shout[:posted]).to be_valid_date_and_match_iso(shout[:posted_at])
        expect(shout[:text]).to be_instance_of String
        expect(shout[:text]).not_to be_blank
      end
    end

    it 'fails when given a non-existent user' do
      expect { @fa.shouts(TEST_USER_NOT_EXIST) }.to raise_error(FASystemError)
    end

    it 'handles an empty shouts list' do
      shouts = @fa.shouts(TEST_USER_NO_SHOUTS)
      expect(shouts).to be_instance_of Array
      expect(shouts).to be_empty
    end
  end
end