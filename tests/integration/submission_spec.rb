
require './lib/faexport'
require_relative 'check_helper'

require 'rspec'

describe 'FA submission page parser' do

  before do
    config = File.exist?('settings-test.yml') ? YAML.load_file('settings-test.yml') : {}
    @app = FAExport::Application.new(config).instance_variable_get(:@instance)
    @fa = @app.instance_variable_get(:@fa)
    @fa.login_cookie = COOKIE_DEFAULT
  end

  after do
    # Do nothing
  end

  it 'displays basic data correctly' do
    sub_id = "16437648"
    sub = @fa.submission(sub_id)
    expect(sub[:title]).not_to be_blank
    expect(sub[:description]).not_to be_blank
    expect(sub[:description_body]).to eql(sub[:description])
    expect(sub).to have_valid_profile_link
    expect(sub[:avatar]).to be_valid_avatar_for_user(sub[:profile_name])
    expect(sub[:link]).to be_valid_link_for_sub_id(sub_id)
    expect(sub[:posted]).to be_valid_date_and_match_iso(sub[:posted_at])
    expect(sub[:download]).to match(/https:\/\/d.facdn.net\/art\/[^\/]+\/[0-9]+\/[0-9]+\..+\.png/)
    # For an image submission, full == download
    expect(sub[:full]).to eql(sub[:download])
    expect(sub[:thumbnail]).to be_valid_thumbnail_link_for_sub_id(sub_id)
    # Info box
    expect(sub[:category]).not_to be_blank
    expect(sub[:theme]).not_to be_blank
    expect(sub[:species]).not_to be_blank
    expect(sub[:gender]).not_to be_blank
    expect(sub[:favorites]).to match(/[0-9]+/)
    expect(sub[:favorites].to_i).to be > 0
    expect(sub[:comments]).to match(/[0-9]+/)
    expect(sub[:comments].to_i).to be > 0
    expect(sub[:views]).to match(/[0-9]+/)
    expect(sub[:views].to_i).to be > 0
    expect(sub[:resolution]).not_to be_blank
    expect(sub[:rating]).not_to be_blank
    expect(sub[:keywords]).to be_instance_of Array
    expect(sub[:keywords]).to eql(%w(keyword1 keyword2 keyword3))
  end

  it 'fails when given non-existent submissions' do
    expect { @fa.submission("16437650") }.to raise_error FASystemError
  end

  it 'parses keywords' do
    sub_id = "16437648"
    sub = @fa.submission(sub_id)
    expect(sub[:keywords]).to be_instance_of Array
    expect(sub[:keywords]).to eql(%w(keyword1 keyword2 keyword3))
  end

  it 'has identical description and description_body' do
    sub = @fa.submission("32006442")
    expect(sub[:description]).not_to be_blank
    expect(sub[:description]).to eql(sub[:description_body])
  end

  it 'displays stories correctly' do
    sub_id = "20438216"
    sub = @fa.submission(sub_id)
    expect(sub[:title]).not_to be_blank
    expect(sub[:description]).not_to be_blank
    expect(sub[:description_body]).to eql(sub[:description])
    expect(sub).to have_valid_profile_link
    expect(sub[:avatar]).to be_valid_avatar_for_user(sub[:profile_name])
    expect(sub[:link]).to be_valid_link_for_sub_id(sub_id)
    expect(sub[:posted]).to be_valid_date_and_match_iso(sub[:posted_at])
    expect(sub[:download]).to match(/https:\/\/d.facdn.net\/download\/art\/[^\/]+\/stories\/[0-9]+\/[0-9]+\..+\.(rtf|doc|txt|docx|pdf)/)
    # For a story submission, full != download
    expect(sub[:full]).not_to be_blank
    expect(sub[:full]).not_to eql(sub[:download])
    expect(sub[:thumbnail]).to be_valid_thumbnail_link_for_sub_id(sub_id)
    # Info box
    expect(sub[:category]).not_to be_blank
    expect(sub[:theme]).not_to be_blank
    expect(sub[:favorites]).to match(/[0-9]+/)
    expect(sub[:favorites].to_i).to be >= 0
    expect(sub[:comments]).to match(/[0-9]+/)
    expect(sub[:comments].to_i).to be >= 0
    expect(sub[:views]).to match(/[0-9]+/)
    expect(sub[:views].to_i).to be > 0
    expect(sub[:resolution]).to be_nil
    expect(sub[:rating]).not_to be_blank
    expect(sub[:keywords]).to be_instance_of Array
    expect(sub[:keywords]).not_to be_empty
    expect(sub[:keywords]).to include("squirrel")
    expect(sub[:keywords]).to include("puma")
  end

  it 'displays music correctly' do
    sub_id = "7009837"
    sub = @fa.submission(sub_id)
    expect(sub[:title]).not_to be_blank
    expect(sub[:description]).not_to be_blank
    expect(sub[:description_body]).to eql(sub[:description])
    expect(sub).to have_valid_profile_link
    expect(sub[:avatar]).to be_valid_avatar_for_user(sub[:profile_name])
    expect(sub[:link]).to be_valid_link_for_sub_id(sub_id)
    expect(sub[:posted]).to be_valid_date_and_match_iso(sub[:posted_at])
    expect(sub[:download]).to match(/https:\/\/d.facdn.net\/download\/art\/[^\/]+\/music\/[0-9]+\/[0-9]+\..+\.(mp3|mid|wav|mpeg)/)
    # For a music submission, full != download
    expect(sub[:full]).not_to be_blank
    expect(sub[:full]).not_to eql(sub[:download])
    expect(sub[:thumbnail]).to be_valid_thumbnail_link_for_sub_id(sub_id)
    # Info box
    expect(sub[:category]).not_to be_blank
    expect(sub[:theme]).not_to be_blank
    expect(sub[:favorites]).to match(/[0-9]+/)
    expect(sub[:favorites].to_i).to be > 0
    expect(sub[:comments]).to match(/[0-9]+/)
    expect(sub[:comments].to_i).to be > 0
    expect(sub[:views]).to match(/[0-9]+/)
    expect(sub[:views].to_i).to be > 0
    expect(sub[:resolution]).to be_nil
    expect(sub[:rating]).not_to be_blank
    expect(sub[:keywords]).to be_instance_of Array
    expect(sub[:keywords]).not_to be_empty
    expect(sub[:keywords]).to include("BLEEP")
    expect(sub[:keywords]).to include("BLORP")
  end

  it 'handles flash files correctly' do
    sub_id = "1586623"
    sub = @fa.submission(sub_id)
    expect(sub[:title]).not_to be_blank
    expect(sub[:description]).not_to be_blank
    expect(sub[:description_body]).to eql(sub[:description])
    expect(sub).to have_valid_profile_link
    expect(sub[:avatar]).to be_valid_avatar_for_user(sub[:profile_name])
    expect(sub[:link]).to be_valid_link_for_sub_id(sub_id)
    expect(sub[:posted]).to be_valid_date_and_match_iso(sub[:posted_at])
    expect(sub[:download]).to match(/https:\/\/d.facdn.net\/download\/art\/[^\/]+\/[0-9]+\/[0-9]+\..+\.swf/)
    # For a flash submission, full is nil
    expect(sub[:full]).to be_nil
    expect(sub[:thumbnail]).to be_valid_thumbnail_link_for_sub_id(sub_id)
    # Info box
    expect(sub[:category]).not_to be_blank
    expect(sub[:theme]).not_to be_blank
    expect(sub[:favorites]).to match(/[0-9]+/)
    expect(sub[:favorites].to_i).to be > 0
    expect(sub[:comments]).to match(/[0-9]+/)
    expect(sub[:comments].to_i).to be > 0
    expect(sub[:views]).to match(/[0-9]+/)
    expect(sub[:views].to_i).to be > 0
    expect(sub[:resolution]).not_to be_blank
    expect(sub[:rating]).not_to be_blank
    expect(sub[:keywords]).to be_instance_of Array
    expect(sub[:keywords]).not_to be_empty
    expect(sub[:keywords]).to include("dog")
    expect(sub[:keywords]).to include("DDR")
  end

  it 'handles poetry submissions correctly' do
    sub_id = "5325854"
    sub = @fa.submission(sub_id)
    expect(sub[:title]).not_to be_blank
    expect(sub[:description]).not_to be_blank
    expect(sub[:description_body]).to eql(sub[:description])
    expect(sub).to have_valid_profile_link
    expect(sub[:avatar]).to be_valid_avatar_for_user(sub[:profile_name])
    expect(sub[:link]).to be_valid_link_for_sub_id(sub_id)
    expect(sub[:posted]).to be_valid_date_and_match_iso(sub[:posted_at])
    expect(sub[:download]).to match(/https:\/\/d.facdn.net\/download\/art\/[^\/]+\/poetry\/[0-9]+\/[0-9]+\..+\.(rtf|doc|txt|docx|pdf)/)
    # For a poetry submission, full is nil
    expect(sub[:full]).not_to be_nil
    expect(sub[:thumbnail]).to be_valid_thumbnail_link_for_sub_id(sub_id)
    # Info box
    expect(sub[:category]).not_to be_blank
    expect(sub[:theme]).not_to be_blank
    expect(sub[:favorites]).to match(/[0-9]+/)
    expect(sub[:favorites].to_i).to be > 0
    expect(sub[:comments]).to match(/[0-9]+/)
    expect(sub[:comments].to_i).to be > 0
    expect(sub[:views]).to match(/[0-9]+/)
    expect(sub[:views].to_i).to be > 0
    expect(sub[:resolution]).to be_blank
    expect(sub[:rating]).not_to be_blank
    expect(sub[:keywords]).to be_instance_of Array
    expect(sub[:keywords]).not_to be_empty
    expect(sub[:keywords]).to include("Love")
    expect(sub[:keywords]).to include("mind")
  end

  it 'still displays correctly when logged in as submission owner' do
    @fa.login_cookie = COOKIE_TEST_USER_2
    expect(@fa.login_cookie).not_to be_nil
    sub_id = "32006442"
    sub = @fa.submission(sub_id)
    expect(sub[:title]).not_to be_blank
    expect(sub[:description]).not_to be_blank
    expect(sub[:description_body]).to eql(sub[:description])
    expect(sub).to have_valid_profile_link
    expect(sub[:avatar]).to be_valid_avatar_for_user(sub[:profile_name])
    expect(sub[:link]).to be_valid_link_for_sub_id(sub_id)
    expect(sub[:posted]).to be_valid_date_and_match_iso(sub[:posted_at])
    expect(sub[:download]).to match(/https:\/\/d.facdn.net\/art\/[^\/]+\/[0-9]+\/[0-9]+\..+\.png/)
    # For an image submission, full == download
    expect(sub[:full]).to eql(sub[:download])
    expect(sub[:thumbnail]).to be_valid_thumbnail_link_for_sub_id(sub_id)
    # Info box
    expect(sub[:category]).not_to be_blank
    expect(sub[:theme]).not_to be_blank
    expect(sub[:species]).not_to be_blank
    expect(sub[:gender]).not_to be_blank
    expect(sub[:favorites]).to match(/[0-9]+/)
    expect(sub[:favorites].to_i).to be >= 0
    expect(sub[:comments]).to match(/[0-9]+/)
    expect(sub[:comments].to_i).to be >= 0
    expect(sub[:views]).to match(/[0-9]+/)
    expect(sub[:views].to_i).to be >= 0
    expect(sub[:resolution]).not_to be_blank
    expect(sub[:rating]).not_to be_blank
    expect(sub[:keywords]).to be_instance_of Array
    expect(sub[:keywords]).to be_empty
  end

  it 'hides nsfw submission if sfw is set' do
    @fa.safe_for_work = true
    expect { @fa.submission("32011278") }.to raise_error(FASystemError)
  end

  it 'should not display the fav status and fav code if not logged in' do
    submission = @fa.submission("32006442", false)
    expect(submission).not_to have_key(:fav_status)
    expect(submission).not_to have_key(:fav_key)
  end

  it 'should display the fav status and fav code when logged in' do
    submission = @fa.submission("32006442", true)
    expect(submission).to have_key(:fav_status)
    expect(submission[:fav_status]).to be_in([true, false])
    expect(submission).to have_key(:fav_key)
    expect(submission[:fav_key]).to be_instance_of String
    expect(submission[:fav_key]).not_to be_empty
  end
end
