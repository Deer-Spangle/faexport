
require './lib/faexport'
require_relative 'check_helper'

require 'rspec'

describe 'FA parser' do

  before do
    config = File.exist?('settings-test.yml') ? YAML.load_file('settings-test.yml') : {}
    @app = FAExport::Application.new(config).instance_variable_get(:@instance)
    @fa = @app.instance_variable_get(:@fa)
    @fa.login_cookie = COOKIE_DEFAULT
  end

  after do
    # Do nothing
  end

  context 'when browsing any page' do
    it 'returns FASystemError if a user has disabled their account' do
      expect { @fa.user("drowsylynx") }.to raise_error(FASystemError)
    end

    it 'returns FAStyleError if the current user is not in classic style' do
      @fa.login_cookie = COOKIE_NOT_CLASSIC
      expect { @fa.home }.to raise_error(FAStyleError)
    end
  end

  context 'when updating favorite status of a submission' do
    it 'should return a valid submission' do
      sub_id = "32006442"
      submission = @fa.submission(sub_id, true)
      is_fav = submission[:fav_status]
      fav_key = submission[:fav_key]

      sub = @fa.favorite_submission(sub_id, !is_fav, fav_key)
      expect(sub[:title]).not_to be_blank
      expect(sub[:description]).not_to be_blank
      expect(sub[:description_body]).to eql(sub[:description])
      expect(sub).to have_valid_profile_link
      expect(sub[:avatar]).to be_valid_avatar_for_user(sub[:profile_name])
      expect(sub[:link]).to be_valid_link_for_sub_id(sub_id)
      expect(sub[:posted]).to be_valid_date_and_match_iso(sub[:posted_at])
      expect(sub[:download]).to match(/https:\/\/d.facdn.net\/art\/[^\/]+\/[0-9]+\/[0-9]+\..+\.png/)
      # For an image submission, full is equal to download
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
    end


    it 'should update the fav status when code is given' do
      id = "32006442"
      submission = @fa.submission(id, true)
      is_fav = submission[:fav_status]
      fav_key = submission[:fav_key]

      new_submission = @fa.favorite_submission(id, !is_fav, fav_key)
      now_fav = new_submission[:fav_status]
      expect(is_fav).to be_in([true, false])
      expect(now_fav).to be_in([true, false])
      expect(is_fav).not_to equal(now_fav)
    end

    it 'should be able to set and unset fav status' do
      id = "32006442"
      submission = @fa.submission(id, true)
      is_fav = submission[:fav_status]
      fav_key = submission[:fav_key]

      new_submission = @fa.favorite_submission(id, !is_fav, fav_key)
      now_fav = new_submission[:fav_status]
      new_key = new_submission[:fav_key]
      expect(now_fav).not_to equal(is_fav)

      new_submission2 = @fa.favorite_submission(id, !now_fav, new_key)
      expect(new_submission2[:fav_status]).to equal(is_fav)
    end

    it 'should not make any change if setting fav status to current value' do
      id = "32006442"
      submission = @fa.submission(id, true)
      is_fav = submission[:fav_status]
      fav_key = submission[:fav_key]

      new_submission = @fa.favorite_submission(id, is_fav, fav_key)
      now_fav = new_submission[:fav_status]
      expect(now_fav).to equal(is_fav)
    end

    it 'should not change fav status if invalid code is given' do
      id = "32006442"
      submission = @fa.submission(id, true)
      is_fav = submission[:fav_status]

      new_submission = @fa.favorite_submission(id, !is_fav, "fake_key")
      now_fav = new_submission[:fav_status]
      expect(now_fav).to equal(is_fav)
    end
  end

  context 'when posting a new journal' do
    it 'requires a login cookie' do
      @fa.login_cookie = nil
      expect { @fa.submit_journal("Do not post", "This journal should fail to post") }.to raise_error(FALoginError)
    end

    it 'fails if not given title' do
      expect { @fa.submit_journal(nil, "No title journal") }.to raise_error(FAFormError)
    end

    it 'fails if not given description' do
      expect { @fa.submit_journal("Title, no desc", nil) }.to raise_error(FAFormError)
    end

    it 'can post a new journal entry' do
      @fa.login_cookie = COOKIE_TEST_USER_JOURNAL_DUMP
      magic_key = (0...5).map { ('a'..'z').to_a[rand(26)] }.join
      long_magic_key = (0...50).map { ('a'..'z').to_a[rand(26)] }.join
      journal_title = "Automatically generated title - #{magic_key}"
      journal_description = "Hello, this is an automatically generated journal.\n Magic key: #{long_magic_key}"

      journal_resp = @fa.submit_journal(journal_title, journal_description)

      expect(journal_resp[:url]).to match(/https:\/\/www.furaffinity.net\/journal\/[0-9]+\//)

      # Get journal listing, ensure latest is this one
      journals = @fa.journals(TEST_USER_JOURNAL_DUMP, 1)
      expect(journals[0][:title]).to eql(journal_title)
      expect(journals[0][:description]).to eql(journal_description.gsub("\n", "<br>\n"))
      expect(journal_resp[:url]).to eql("https://www.furaffinity.net/journal/#{journals[0][:id]}/")
    end
  end

  context 'when checking FA status' do
    it 'displays the usual status information' do
      status = @fa.status

      expect(status).to be_valid_status_data
    end

    it 'displays status information after another page load' do
      status_1 = @fa.status
      @fa.home
      status_2 = @fa.status

      expect(status_1).to be_valid_status_data
      expect(status_2).to be_valid_status_data
    end
  end
end