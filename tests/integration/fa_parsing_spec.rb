# frozen_string_literal: true

require "./lib/faexport"
require_relative "check_helper"

require "rspec"

COOKIE_DEFAULT = ENV["test_cookie"]
TEST_USER = "fafeed"
TEST_USER_2 = "fafeed-2"
COOKIE_TEST_USER_2 = ENV["test_cookie_user_2"]
TEST_USER_3 = "fafeed-3"
COOKIE_TEST_USER_3 = ENV["test_cookie_user_3"]
# Specific test user cases
TEST_USER_NOT_EXIST = "fafeed-does-not-exist"
TEST_USER_WITH_BRACKETS = "l[i]s"
TEST_USER_OVER_200_WATCHERS = "fender"
TEST_USER_NO_WATCHERS = "fafeed-no-watchers"
TEST_USER_NO_JOURNALS = TEST_USER_NO_WATCHERS
TEST_USER_NO_SHOUTS = TEST_USER_NO_WATCHERS
TEST_USER_OVER_25_JOURNALS = TEST_USER_OVER_200_WATCHERS
TEST_USER_EMPTY_GALLERIES = TEST_USER_NO_WATCHERS
TEST_USER_2_PAGES_GALLERY = "rajii"
TEST_USER_HIDDEN_FAVS = TEST_USER_NO_WATCHERS
COOKIE_TEST_USER_HIDDEN_FAVS = ENV["test_cookie_hidden_favs"]
TEST_USER_2_PAGES_FAVS = TEST_USER_2_PAGES_GALLERY
COOKIE_TEST_USER_NO_NOTIFICATIONS = COOKIE_TEST_USER_HIDDEN_FAVS
TEST_USER_JOURNAL_DUMP = TEST_USER_3
COOKIE_TEST_USER_JOURNAL_DUMP = COOKIE_TEST_USER_3
COOKIE_NOT_CLASSIC = ENV["test_cookie_not_classic"]

describe "FA parser" do
  before do
    config = File.exist?("settings-test.yml") ? YAML.load_file("settings-test.yml") : {}
    @app = FAExport::Application.new(config).instance_variable_get(:@instance)
    @fa = @app.instance_variable_get(:@fa)
    @fa.login_cookie = COOKIE_DEFAULT
  end

  after do
    # Do nothing
  end

  context "when browsing any page" do
    it "returns FASystemError if a user has disabled their account" do
      expect { @fa.user("drowsylynx") }.to raise_error(FASystemError)
    end

    it "returns FAStyleError if the current user is not in classic style" do
      @fa.login_cookie = COOKIE_NOT_CLASSIC
      expect { @fa.home }.to raise_error(FAStyleError)
    end
  end

  context "when getting home page data" do
    it "has the 4 submission types" do
      home = @fa.home
      expect(home).to have_key(:artwork)
      expect(home).to have_key(:writing)
      expect(home).to have_key(:music)
      expect(home).to have_key(:crafts)
    end

    it "has valid submissions in all categories" do
      home = @fa.home
      keys = %i[artwork writing music crafts]
      home.map do |type, submissions|
        expect(keys).to include(type)
        expect(submissions).not_to be_empty
        submissions.each do |submission|
          expect(submission).to be_valid_submission
        end
      end
    end

    it "only returns SFW results, if specified" do
      @fa.safe_for_work = true
      home = @fa.home
      home.map do |_, submissions|
        expect(submissions).not_to be_empty
        submissions.map do |submission|
          begin
            full_submission = @fa.submission(submission[:id])
            expect(full_submission[:rating]).to eql("General")
          rescue FASystemError
            nil
          end
        end
      end
    end
  end

  context "when getting user profile" do
    it "gives valid basic profile information" do
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
      %i[pageviews submissions comments_received comments_given journals favorites].each do |key|
        expect(profile[key]).not_to be_blank
        expect(profile[key]).to match(/^[0-9]+$/)
      end
    end

    it "fails when given a non-existent profile" do
      expect { @fa.user(TEST_USER_NOT_EXIST) }.to raise_error(FASystemError)
    end

    it "handles square brackets in profile name" do
      profile_with_underscores = TEST_USER_WITH_BRACKETS
      profile = @fa.user(profile_with_underscores)
      expect(profile[:name].downcase).to eql(profile_with_underscores)
    end

    it "shows featured submission" do
      profile = @fa.user(TEST_USER_2)
      expect(profile[:featured_submission]).not_to be_nil
      expect(profile[:featured_submission]).to be_valid_submission(true)
    end

    it "handles featured submission not being set" do
      profile = @fa.user(TEST_USER)
      expect(profile[:featured_submission]).to be_nil
    end

    it "shows profile id" do
      profile = @fa.user(TEST_USER_2)
      expect(profile[:profile_id]).not_to be_nil
      expect(profile[:profile_id]).to be_valid_submission(true, true)
    end

    it "handles profile id not being set" do
      profile = @fa.user(TEST_USER)
      expect(profile[:profile_id]).to be_nil
    end

    it "shows artist information" do
      profile = @fa.user(TEST_USER_2)
      expect(profile[:artist_information]).to be_instance_of Hash
      expect(profile[:artist_information]).to have_key("Species")
      expect(profile[:artist_information]["Species"]).to eql("Robot")
      expect(profile[:artist_information]).to have_key("Shell of Choice")
      expect(profile[:artist_information]["Shell of Choice"]).to eql("irb")
      expect(profile[:artist_information]).to have_key("Favorite Website")
      expect(profile[:artist_information]["Favorite Website"]).to start_with("<a href=")
      expect(profile[:artist_information]["Favorite Website"]).to include("https://www.ruby-lang.org")
      expect(profile[:artist_information]["Favorite Website"]).to end_with("</a>")
      expect(profile[:artist_information]).not_to have_key("Personal quote")
      # Maybe do all the available fields, that way we can know of any removed?
    end

    it "handles blank artist information box" do
      profile = @fa.user(TEST_USER)
      expect(profile[:artist_information]).to be_instance_of Hash
      expect(profile[:artist_information]).to be_empty
    end

    it "shows contact information" do
      profile = @fa.user(TEST_USER_2)
      expect(profile[:contact_information]).to be_instance_of Array
      expect(profile[:contact_information]).not_to be_empty
      profile[:contact_information].each do |item|
        expect(item[:title]).not_to be_blank
        expect(item[:name]).not_to be_blank
        expect(item).to have_key(:link)
      end
    end

    it "handles no contact information being set" do
      profile = @fa.user(TEST_USER)
      expect(profile[:profile_id]).to be_nil
    end

    it "lists watchers of specified account" do
      profile = @fa.user(TEST_USER)
      expect(profile[:watchers]).to be_instance_of Hash
      expect(profile[:watchers][:count]).to be_instance_of Integer
      expect(profile[:watchers][:count]).to be.positive?
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

    it "lists accounts watched by specified account" do
      profile = @fa.user(TEST_USER)
      expect(profile[:watching]).to be_instance_of Hash
      expect(profile[:watching][:count]).to be_instance_of Integer
      expect(profile[:watching][:count]).to be.positive?
      expect(profile[:watching][:recent]).to be_instance_of Array
      expect(profile[:watching][:recent].length).to be <= profile[:watching][:count]
      profile[:watching][:recent].each do |item|
        expect(item).to have_valid_profile_link(true)
      end
    end
  end

  context "when listing user's watchers/watchees" do
    [true, false].each do |is_watchers|
      it "displays a valid list of profile names" do
        list = @fa.budlist(TEST_USER, 1, is_watchers)
        expect(list).to be_instance_of Array
        expect(list).not_to be_empty
        list.each do |bud|
          expect(bud).to be_instance_of String
          expect(bud).not_to be_blank
        end
      end

      it "fails when given a non-existent profile" do
        expect { @fa.budlist(TEST_USER_NOT_EXIST, 1, is_watchers) }.to raise_error(FASystemError)
      end

      it "handles an empty watchers list" do
        bud_list = @fa.budlist(TEST_USER_NO_WATCHERS, 1, is_watchers)
        expect(bud_list).to be_instance_of Array
        expect(bud_list).to be_empty
      end
    end

    it "displays a different list for is watching vs watched by" do
      expect(@fa.budlist(TEST_USER, 1, true)).not_to eql(@fa.budlist(TEST_USER, 1, false))
    end

    it "returns 200 users when more than one page exists" do
      bud_list = @fa.budlist(TEST_USER_OVER_200_WATCHERS, 1, true)
      expect(bud_list).to be_instance_of Array
      expect(bud_list.length).to eql(200)
      bud_list.each do |bud|
        expect(bud).to be_instance_of String
        expect(bud).not_to be_blank
      end
    end

    it "displays a second page, different than the first" do
      bud_list1 = @fa.budlist(TEST_USER_OVER_200_WATCHERS, 1, true)
      bud_list2 = @fa.budlist(TEST_USER_OVER_200_WATCHERS, 2, true)
      expect(bud_list1).to be_instance_of Array
      expect(bud_list1.length).to eql(200)
      expect(bud_list2).to be_instance_of Array
      expect(bud_list1).not_to eql(bud_list2)
    end
  end

  context "when listing a user's shouts" do
    it "displays a valid list of shouts" do
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

    it "fails when given a non-existent user" do
      expect { @fa.shouts(TEST_USER_NOT_EXIST) }.to raise_error(FASystemError)
    end

    it "handles an empty shouts list" do
      shouts = @fa.shouts(TEST_USER_NO_SHOUTS)
      expect(shouts).to be_instance_of Array
      expect(shouts).to be_empty
    end
  end

  context "when displaying commission information pages" do
    it "handles empty commission information" do
      comms = @fa.commissions(TEST_USER)
      expect(comms).to be_instance_of Array
      expect(comms).to be_empty
    end

    it "displays valid commission information data" do
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

    it "fails when given a non-existent user" do
      expect { @fa.shouts(TEST_USER_NOT_EXIST) }.to raise_error(FASystemError)
    end
  end

  context "when listing a user's journals" do
    it "returns a list of journal IDs" do
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

    it "fails when given a non-existent user" do
      expect { @fa.journals(TEST_USER_NOT_EXIST, 1) }.to raise_error(FASystemError)
    end

    it "handles an empty journal listing" do
      journals = @fa.journals(TEST_USER_NO_JOURNALS, 1)
      expect(journals).to be_instance_of Array
      expect(journals).to be_empty
    end

    it "displays a second page, different than the first" do
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

  context "when viewing user galleries" do
    %w[gallery scraps favorites].each do |folder|
      it "returns a list of valid submission" do
        submissions = @fa.submissions(TEST_USER_2, folder, {})
        expect(submissions).to be_instance_of Array
        expect(submissions).not_to be_empty
        submissions.each do |submission|
          expect(submission).to be_valid_submission
        end
      end

      it "fails when given a non-existent user" do
        expect { @fa.submissions(TEST_USER_NOT_EXIST, folder, {}) }.to raise_error(FASystemError)
      end

      it "handles an empty gallery" do
        submissions = @fa.submissions(TEST_USER_EMPTY_GALLERIES, folder, {})
        expect(submissions).to be_instance_of Array
        expect(submissions).to be_empty
      end

      it "hides nsfw submissions if sfw is set" do
        all_submissions = @fa.submissions(TEST_USER_2, folder, {})
        @fa.safe_for_work = true
        sfw_submissions = @fa.submissions(TEST_USER_2, folder, {})
        expect(all_submissions).not_to eql(sfw_submissions)
        expect(all_submissions.length).to be > sfw_submissions.length
        sfw_submissions.each do |submission|
          full_submission = @fa.submission(submission[:id])
          expect(full_submission[:rating]).to eql("General")
        end
      end
    end

    context "specifically gallery or scraps" do
      %w[gallery scraps].each do |folder|
        it "handles paging correctly" do
          gallery1 = @fa.submissions(TEST_USER_2_PAGES_GALLERY, folder, {})
          gallery2 = @fa.submissions(TEST_USER_2_PAGES_GALLERY, folder, { page: 2 })
          expect(gallery1).to be_instance_of Array
          expect(gallery2).to be_instance_of Array
          expect(gallery1).not_to eql(gallery2)
        end
      end
    end

    context "specifically favourites" do
      it "handles a hidden favourites list" do
        favs = @fa.submissions(TEST_USER_HIDDEN_FAVS, "favorites", {})
        expect(favs).to be_instance_of Array
        expect(favs).to be_empty
      end

      it "displays favourites of currently logged in user even if hidden" do
        @fa.login_cookie = COOKIE_TEST_USER_HIDDEN_FAVS
        expect(@fa.login_cookie).not_to be_nil
        favs = @fa.submissions(TEST_USER_HIDDEN_FAVS, "favorites", {})
        expect(favs).to be_instance_of Array
        expect(favs).not_to be_empty
      end

      it "uses next parameter to display submissions after a specified fav id" do
        favs = @fa.submissions(TEST_USER_2_PAGES_FAVS, "favorites", {})
        expect(favs).to be_instance_of Array
        expect(favs.length).to be 72
        # Get fav ID partially down
        fav_id = favs[58][:fav_id]
        fav_id_next = favs[59][:fav_id]
        # Get favs after that ID
        favs_next = @fa.submissions(TEST_USER_2_PAGES_FAVS, "favorites", { next: fav_id })
        expect(favs_next.length).to be > (72 - 58)
        expect(favs_next[0][:fav_id]).to eql(fav_id_next)
        favs_next.each do |fav|
          expect(fav[:fav_id]).to be < fav_id
        end
      end

      it "uses prev parameter to display only submissions before a specified fav id" do
        favs1 = @fa.submissions(TEST_USER_2_PAGES_FAVS, "favorites", {})
        expect(favs1).to be_instance_of Array
        expect(favs1.length).to be 72
        last_fav_id = favs1[71][:fav_id]
        favs2 = @fa.submissions(TEST_USER_2_PAGES_FAVS, "favorites", { next: last_fav_id })
        # Get fav ID partially through
        overlap_fav_id = favs2[5][:fav_id]
        favs_overlap = @fa.submissions(TEST_USER_2_PAGES_FAVS, "favorites", { prev: overlap_fav_id })
        expect(favs1).to be_instance_of Array
        expect(favs1.length).to be 72
        favs_overlap.each do |fav|
          expect(fav[:fav_id]).to be > overlap_fav_id
        end
      end
    end
  end

  context "when viewing a submission" do
    it "displays basic data correctly" do
      sub_id = "16437648"
      sub = @fa.submission(sub_id)
      expect(sub[:title]).not_to be_blank
      expect(sub[:description]).not_to be_blank
      expect(sub[:description_body]).to eql(sub[:description])
      expect(sub).to have_valid_profile_link
      expect(sub[:avatar]).to be_valid_avatar_for_user(sub[:profile_name])
      expect(sub[:link]).to be_valid_link_for_sub_id(sub_id)
      expect(sub[:posted]).to be_valid_date_and_match_iso(sub[:posted_at])
      expect(sub[:download]).to match(%r{https://d.furaffinity.net/art/[^/]+/[0-9]+/[0-9]+\..+\.png})
      # For an image submission, full == download
      expect(sub[:full]).to eql(sub[:download])
      expect(sub[:thumbnail]).to be_valid_thumbnail_link_for_sub_id(sub_id)
      # Info box
      expect(sub[:category]).not_to be_blank
      expect(sub[:theme]).not_to be_blank
      expect(sub[:species]).not_to be_blank
      expect(sub[:gender]).not_to be_blank
      expect(sub[:favorites]).to match(/[0-9]+/)
      expect(sub[:favorites].to_i).to be.positive?
      expect(sub[:comments]).to match(/[0-9]+/)
      expect(sub[:comments].to_i).to be.positive?
      expect(sub[:views]).to match(/[0-9]+/)
      expect(sub[:views].to_i).to be.positive?
      expect(sub[:resolution]).not_to be_blank
      expect(sub[:rating]).not_to be_blank
      expect(sub[:keywords]).to be_instance_of Array
      expect(sub[:keywords]).to eql(%w[keyword1 keyword2 keyword3])
    end

    it "fails when given non-existent submissions" do
      expect { @fa.submission("16437650") }.to raise_error FASystemError
    end

    it "parses keywords" do
      sub_id = "16437648"
      sub = @fa.submission(sub_id)
      expect(sub[:keywords]).to be_instance_of Array
      expect(sub[:keywords]).to eql(%w[keyword1 keyword2 keyword3])
    end

    it "has identical description and description_body" do
      sub = @fa.submission("32006442")
      expect(sub[:description]).not_to be_blank
      expect(sub[:description]).to eql(sub[:description_body])
    end

    it "displays stories correctly" do
      sub_id = "20438216"
      sub = @fa.submission(sub_id)
      expect(sub[:title]).not_to be_blank
      expect(sub[:description]).not_to be_blank
      expect(sub[:description_body]).to eql(sub[:description])
      expect(sub).to have_valid_profile_link
      expect(sub[:avatar]).to be_valid_avatar_for_user(sub[:profile_name])
      expect(sub[:link]).to be_valid_link_for_sub_id(sub_id)
      expect(sub[:posted]).to be_valid_date_and_match_iso(sub[:posted_at])
      expect(sub[:download]).to match(%r{https://d.furaffinity.net/download/art/[^/]+/stories/[0-9]+/[0-9]+\..+\.(rtf|doc|txt|docx|pdf)})
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
      expect(sub[:views].to_i).to be.positive?
      expect(sub[:resolution]).to be_nil
      expect(sub[:rating]).not_to be_blank
      expect(sub[:keywords]).to be_instance_of Array
      expect(sub[:keywords]).not_to be_empty
      expect(sub[:keywords]).to include("squirrel")
      expect(sub[:keywords]).to include("puma")
    end

    it "displays music correctly" do
      sub_id = "7009837"
      sub = @fa.submission(sub_id)
      expect(sub[:title]).not_to be_blank
      expect(sub[:description]).not_to be_blank
      expect(sub[:description_body]).to eql(sub[:description])
      expect(sub).to have_valid_profile_link
      expect(sub[:avatar]).to be_valid_avatar_for_user(sub[:profile_name])
      expect(sub[:link]).to be_valid_link_for_sub_id(sub_id)
      expect(sub[:posted]).to be_valid_date_and_match_iso(sub[:posted_at])
      expect(sub[:download]).to match(%r{https://d.furaffinity.net/download/art/[^/]+/music/[0-9]+/[0-9]+\..+\.(mp3|mid|wav|mpeg)})
      # For a music submission, full != download
      expect(sub[:full]).not_to be_blank
      expect(sub[:full]).not_to eql(sub[:download])
      expect(sub[:thumbnail]).to be_valid_thumbnail_link_for_sub_id(sub_id)
      # Info box
      expect(sub[:category]).not_to be_blank
      expect(sub[:theme]).not_to be_blank
      expect(sub[:favorites]).to match(/[0-9]+/)
      expect(sub[:favorites].to_i).to be.positive?
      expect(sub[:comments]).to match(/[0-9]+/)
      expect(sub[:comments].to_i).to be.positive?
      expect(sub[:views]).to match(/[0-9]+/)
      expect(sub[:views].to_i).to be.positive?
      expect(sub[:resolution]).to be_nil
      expect(sub[:rating]).not_to be_blank
      expect(sub[:keywords]).to be_instance_of Array
      expect(sub[:keywords]).not_to be_empty
      expect(sub[:keywords]).to include("BLEEP")
      expect(sub[:keywords]).to include("BLORP")
    end

    it "handles flash files correctly" do
      sub_id = "1586623"
      sub = @fa.submission(sub_id)
      expect(sub[:title]).not_to be_blank
      expect(sub[:description]).not_to be_blank
      expect(sub[:description_body]).to eql(sub[:description])
      expect(sub).to have_valid_profile_link
      expect(sub[:avatar]).to be_valid_avatar_for_user(sub[:profile_name])
      expect(sub[:link]).to be_valid_link_for_sub_id(sub_id)
      expect(sub[:posted]).to be_valid_date_and_match_iso(sub[:posted_at])
      expect(sub[:download]).to match(%r{https://d.furaffinity.net/download/art/[^/]+/[0-9]+/[0-9]+\..+\.swf})
      # For a flash submission, full is nil
      expect(sub[:full]).to be_nil
      expect(sub[:thumbnail]).to be_valid_thumbnail_link_for_sub_id(sub_id)
      # Info box
      expect(sub[:category]).not_to be_blank
      expect(sub[:theme]).not_to be_blank
      expect(sub[:favorites]).to match(/[0-9]+/)
      expect(sub[:favorites].to_i).to be.positive?
      expect(sub[:comments]).to match(/[0-9]+/)
      expect(sub[:comments].to_i).to be.positive?
      expect(sub[:views]).to match(/[0-9]+/)
      expect(sub[:views].to_i).to be.positive?
      expect(sub[:resolution]).not_to be_blank
      expect(sub[:rating]).not_to be_blank
      expect(sub[:keywords]).to be_instance_of Array
      expect(sub[:keywords]).not_to be_empty
      expect(sub[:keywords]).to include("dog")
      expect(sub[:keywords]).to include("DDR")
    end

    it "handles poetry submissions correctly" do
      sub_id = "5325854"
      sub = @fa.submission(sub_id)
      expect(sub[:title]).not_to be_blank
      expect(sub[:description]).not_to be_blank
      expect(sub[:description_body]).to eql(sub[:description])
      expect(sub).to have_valid_profile_link
      expect(sub[:avatar]).to be_valid_avatar_for_user(sub[:profile_name])
      expect(sub[:link]).to be_valid_link_for_sub_id(sub_id)
      expect(sub[:posted]).to be_valid_date_and_match_iso(sub[:posted_at])
      expect(sub[:download]).to match(%r{https://d.furaffinity.net/download/art/[^/]+/poetry/[0-9]+/[0-9]+\..+\.(rtf|doc|txt|docx|pdf)})
      # For a poetry submission, full is nil
      expect(sub[:full]).not_to be_nil
      expect(sub[:thumbnail]).to be_valid_thumbnail_link_for_sub_id(sub_id)
      # Info box
      expect(sub[:category]).not_to be_blank
      expect(sub[:theme]).not_to be_blank
      expect(sub[:favorites]).to match(/[0-9]+/)
      expect(sub[:favorites].to_i).to be.positive?
      expect(sub[:comments]).to match(/[0-9]+/)
      expect(sub[:comments].to_i).to be.positive?
      expect(sub[:views]).to match(/[0-9]+/)
      expect(sub[:views].to_i).to be.positive?
      expect(sub[:resolution]).to be_blank
      expect(sub[:rating]).not_to be_blank
      expect(sub[:keywords]).to be_instance_of Array
      expect(sub[:keywords]).not_to be_empty
      expect(sub[:keywords]).to include("Love")
      expect(sub[:keywords]).to include("mind")
    end

    it "still displays correctly when logged in as submission owner" do
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
      expect(sub[:download]).to match(%r{https://d.furaffinity.net/art/[^/]+/[0-9]+/[0-9]+\..+\.png})
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

    it "hides nsfw submission if sfw is set" do
      @fa.safe_for_work = true
      expect { @fa.submission("32011278") }.to raise_error(FASystemError)
    end

    it "should not display the fav status and fav code if not logged in" do
      submission = @fa.submission("32006442", false)
      expect(submission).not_to have_key(:fav_status)
      expect(submission).not_to have_key(:fav_key)
    end

    it "should display the fav status and fav code when logged in" do
      submission = @fa.submission("32006442", true)
      expect(submission).to have_key(:fav_status)
      expect(submission[:fav_status]).to be_in([true, false])
      expect(submission).to have_key(:fav_key)
      expect(submission[:fav_key]).to be_instance_of String
      expect(submission[:fav_key]).not_to be_empty
    end

    it "should give a non-null thumbnail link for sfw submissions" do
      submission = @fa.submission("32006442")
      expect(submission).to have_key(:thumbnail)
      expect(submission[:thumbnail]).not_to be_nil
      expect(submission[:rating]).to eql("General")
    end

    it "should give a non-null thumbnail link for nsfw submissions" do
      submission = @fa.submission("32011278")
      expect(submission).to have_key(:thumbnail)
      expect(submission[:thumbnail]).not_to be_nil
      expect(submission[:rating]).to eql("Adult")
    end

    it "should give a non-null thumbnail link for stories" do
      submission = @fa.submission("20438216")
      expect(submission).to have_key(:thumbnail)
      expect(submission[:thumbnail]).not_to be_nil
      expect(submission[:rating]).to eql("General")
    end

    it "should give a non-null thumbnail link for stories without a set image" do
      submission = @fa.submission("572932")
      expect(submission).to have_key(:thumbnail)
      expect(submission[:thumbnail]).not_to be_nil
    end
  end

  context "when updating favorite status of a submission" do
    it "should return a valid submission" do
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
      expect(sub[:download]).to match(%r{https://d.furaffinity.net/art/[^/]+/[0-9]+/[0-9]+\..+\.png})
      # For an image submission, full is equal to download
      expect(sub[:full]).to eql(sub[:download])
      expect(sub[:thumbnail]).to be_valid_thumbnail_link_for_sub_id(sub_id)
      # Info box
      expect(sub[:category]).not_to be_blank
      expect(sub[:theme]).not_to be_blank
      expect(sub[:species]).not_to be_blank
      expect(sub[:gender]).not_to be_blank
      expect(sub[:favorites]).to match(/[0-9]+/)
      expect(sub[:favorites].to_i).to be.positive?
      expect(sub[:comments]).to match(/[0-9]+/)
      expect(sub[:comments].to_i).to be.positive?
      expect(sub[:views]).to match(/[0-9]+/)
      expect(sub[:views].to_i).to be.positive?
      expect(sub[:resolution]).not_to be_blank
      expect(sub[:rating]).not_to be_blank
      expect(sub[:keywords]).to be_instance_of Array
    end

    it "should update the fav status when code is given" do
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

    it "should be able to set and unset fav status" do
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

    it "should not make any change if setting fav status to current value" do
      id = "32006442"
      submission = @fa.submission(id, true)
      is_fav = submission[:fav_status]
      fav_key = submission[:fav_key]

      new_submission = @fa.favorite_submission(id, is_fav, fav_key)
      now_fav = new_submission[:fav_status]
      expect(now_fav).to equal(is_fav)
    end

    it "should not change fav status if invalid code is given" do
      id = "32006442"
      submission = @fa.submission(id, true)
      is_fav = submission[:fav_status]

      new_submission = @fa.favorite_submission(id, !is_fav, "fake_key")
      now_fav = new_submission[:fav_status]
      expect(now_fav).to equal(is_fav)
    end
  end

  context "when viewing a journal post" do
    it "displays basic data correctly" do
      journal_id = "6894930"
      journal = @fa.journal(journal_id)
      expect(journal[:title]).to eql("From Curl")
      expect(journal[:description]).to start_with("<div class=\"journal-body\">")
      expect(journal[:description]).to include("Curl Test")
      expect(journal[:description]).to end_with("</div>")
      expect(journal[:journal_header]).to be_nil
      expect(journal[:journal_body]).to eql("Curl Test")
      expect(journal[:journal_footer]).to be_nil
      expect(journal).to have_valid_profile_link
      expect(journal[:avatar]).to be_valid_avatar_for_user(journal[:profile_name])
      expect(journal[:link]).to match(%r{https://www.furaffinity.net/journal/#{journal_id}/?})
      expect(journal[:posted]).to be_valid_date_and_match_iso(journal[:posted_at])
    end

    it "fails when given non-existent journal" do
      expect { @fa.journal("6894929") }.to raise_error(FASystemError)
    end

    it "parses journal header, body and footer" do
      journal_id = "9185920"
      journal = @fa.journal(journal_id)
      expect(journal[:title]).to eql("Test journal")
      expect(journal[:description]).to start_with("<div class=\"journal-header\">")
      expect(journal[:description]).to include("Example test header")
      expect(journal[:description]).to include("<div class=\"journal-body\">")
      expect(journal[:description]).to include("This is an example test journal, with header and footer")
      expect(journal[:description]).to include("<div class=\"journal-footer\">")
      expect(journal[:description]).to include("Example test footer")
      expect(journal[:description]).to end_with("</div>")
      expect(journal[:journal_header]).to eql("Example test header")
      expect(journal[:journal_body]).to eql("This is an example test journal, with header and footer")
      expect(journal[:journal_footer]).to eql("Example test footer")
      expect(journal).to have_valid_profile_link
      expect(journal[:avatar]).to be_valid_avatar_for_user(journal[:profile_name])
      expect(journal[:link]).to match(%r{https://www.furaffinity.net/journal/#{journal_id}/?})
      expect(journal[:posted]).to be_valid_date_and_match_iso(journal[:posted_at])
    end

    it "handles non existent journal header" do
      journal_id = "9185944"
      journal = @fa.journal(journal_id)
      expect(journal[:title]).to eql("Testing journals")
      expect(journal[:description]).to start_with("<div class=\"journal-body\">")
      expect(journal[:description]).to include("Another test of journals, this one is for footer only")
      expect(journal[:description]).to include("<div class=\"journal-footer\">")
      expect(journal[:description]).to include("Footer, no header though")
      expect(journal[:description]).to end_with("</div>")
      expect(journal[:journal_header]).to be_nil
      expect(journal[:journal_body]).to eql("Another test of journals, this one is for footer only")
      expect(journal[:journal_footer]).to eql("Footer, no header though")
      expect(journal).to have_valid_profile_link
      expect(journal[:avatar]).to be_valid_avatar_for_user(journal[:profile_name])
      expect(journal[:link]).to match(%r{https://www.furaffinity.net/journal/#{journal_id}/?})
      expect(journal[:posted]).to be_valid_date_and_match_iso(journal[:posted_at])
    end
  end

  context "when listing comments" do
    context "on a submission" do
      it "displays a valid list of top level comments" do
        sub_id = "16437648"
        comments = @fa.submission_comments(sub_id, false)
        expect(comments).to be_instance_of Array
        expect(comments).not_to be_empty
        comments.each do |comment|
          expect(comment[:id]).to match(/[0-9]+/)
          expect(comment).to have_valid_profile_link
          expect(comment[:avatar]).to be_valid_avatar_for_user(comment[:profile_name])
          expect(comment[:posted]).to be_valid_date_and_match_iso(comment[:posted_at])
          expect(comment[:text]).not_to be_blank
          expect(comment[:reply_to]).to be_blank
          expect(comment[:reply_level]).to be 0
        end
      end

      it "handles empty comments section" do
        sub_id = "16437675"
        comments = @fa.submission_comments(sub_id, false)
        expect(comments).to be_instance_of Array
        expect(comments).to be_empty
      end

      it "hides deleted comments by default" do
        submission_id = "16437663"
        comments = @fa.submission_comments(submission_id, false)
        expect(comments).to be_instance_of Array
        expect(comments.length).to be 1
        expect(comments[0][:text]).to eql("Non-deleted comment")
      end

      it "handles comments deleted by author when specified" do
        submission_id = "16437663"
        comments = @fa.submission_comments(submission_id, true)
        expect(comments).to be_instance_of Array
        expect(comments.length).to be 2
        expect(comments[0]).to have_key(:id)
        expect(comments[0][:text]).to eql("Non-deleted comment")
        expect(comments[0][:is_deleted]).to be false
        expect(comments[1]).to have_key(:id)
        expect(comments[1][:text]).to eql("Comment hidden by its owner")
        expect(comments[1][:is_deleted]).to be true
      end

      it "handles comments deleted by submission owner when specified" do
        submission_id = "32006442"
        comments_not_deleted = @fa.submission_comments(submission_id, false)
        expect(comments_not_deleted).to be_instance_of Array
        expect(comments_not_deleted).to be_empty
        # Ensure comments appear when viewing deleted
        comments = @fa.submission_comments(submission_id, true)
        expect(comments).to be_instance_of Array
        expect(comments.length).to be 1
        expect(comments[0]).to have_key(:id)
        expect(comments[0][:text]).to eql("Comment hidden by  the page owner")
        expect(comments[0][:is_deleted]).to be true
      end

      it "fails when given non-existent submission" do
        expect { @fa.submission_comments("16437650", false) }.to raise_error FASystemError
      end

      it "correctly parses replies and reply levels" do
        comments = @fa.submission_comments("32006460", false)
        # Check first comment
        expect(comments[0][:id]).not_to be_blank
        expect(comments[0][:profile_name]).to eql(TEST_USER_3)
        expect(comments[0]).to have_valid_profile_link
        expect(comments[0][:avatar]).to be_valid_avatar_for_user(comments[0][:profile_name])
        expect(comments[0][:posted]).to be_valid_date_and_match_iso(comments[0][:posted_at])
        expect(comments[0][:text]).to eql("Base comment")
        expect(comments[0][:reply_to]).to be_blank
        expect(comments[0][:reply_level]).to be 0
        # Check second comment
        expect(comments[1][:id]).not_to be_blank
        expect(comments[1][:profile_name]).to eql(TEST_USER_3)
        expect(comments[1]).to have_valid_profile_link
        expect(comments[1][:avatar]).to be_valid_avatar_for_user(comments[1][:profile_name])
        expect(comments[1][:posted]).to be_valid_date_and_match_iso(comments[1][:posted_at])
        expect(comments[1][:text]).to eql("First reply")
        expect(comments[1][:reply_to]).not_to be_blank
        expect(comments[1][:reply_to]).to eql(comments[0][:id])
        expect(comments[1][:reply_level]).to be 1
        # Check third comment
        expect(comments[2][:id]).not_to be_blank
        expect(comments[2][:profile_name]).to eql("fafeed-no-watchers")
        expect(comments[2]).to have_valid_profile_link
        expect(comments[2][:avatar]).to be_valid_avatar_for_user(comments[2][:profile_name])
        expect(comments[2][:posted]).to be_valid_date_and_match_iso(comments[2][:posted_at])
        expect(comments[2][:text]).to eql("Another reply")
        expect(comments[2][:reply_to]).not_to be_blank
        expect(comments[2][:reply_to]).to eql(comments[1][:id])
        expect(comments[2][:reply_level]).to be 2
      end

      it "handles replies to deleted comments" do
        comments = @fa.submission_comments("32052941", true)
        expect(comments).to be_instance_of Array
        expect(comments.length).to be 2
        # Check hidden comment
        expect(comments[1][:id]).not_to be_blank
        expect(comments[0][:text]).to start_with("Comment hidden by")
        expect(comments[0][:reply_to]).to eql("")
        expect(comments[0][:reply_level]).to be 0
        expect(comments[0][:is_deleted]).to be true
        # Check reply comment
        expect(comments[1][:id]).not_to be_blank
        expect(comments[1][:text]).not_to start_with("Comment hidden by")
        expect(comments[1]).to have_key(:profile_name)
        expect(comments[1][:reply_level]).to be 1
        expect(comments[1][:reply_to]).not_to be_blank
        expect(comments[1][:is_deleted]).to be false
      end

      it "handles replies to hidden deleted comments" do
        comments = @fa.submission_comments("32052941", false)
        expect(comments).to be_instance_of Array
        expect(comments.length).to be 1
        # Reply comment should be only comment
        expect(comments[0][:id]).not_to be_blank
        expect(comments[0][:text]).not_to start_with("Comment hidden by")
        expect(comments[0]).to have_key(:profile_name)
        expect(comments[0][:reply_level]).to be 1
        expect(comments[0][:reply_to]).not_to be_blank
      end

      it "handles 2 replies to the same comment" do
        comments = @fa.submission_comments("32057670", false)
        expect(comments).to be_instance_of Array
        expect(comments.length).to be 3
        # Base comment
        expect(comments[0][:id]).not_to be_blank
        expect(comments[0][:text]).to eql("Base level comment")
        expect(comments[0][:reply_level]).to be 0
        expect(comments[0][:reply_to]).to eql("")
        # First reply
        expect(comments[1][:id]).not_to be_blank
        expect(comments[1][:text]).to eql("First reply comment")
        expect(comments[1][:reply_level]).to be 1
        expect(comments[1][:reply_to]).to eql(comments[0][:id])
        # Second reply
        expect(comments[2][:id]).not_to be_blank
        expect(comments[2][:text]).to eql("Second reply comment")
        expect(comments[2][:reply_level]).to be 1
        expect(comments[2][:reply_to]).to eql(comments[0][:id])
      end

      it "handles deleted replies to deleted comments" do
        comments = @fa.submission_comments("32057697", true)
        expect(comments).to be_instance_of Array
        expect(comments.length).to be 2
        # Check hidden comment
        expect(comments[0][:id]).not_to be_blank
        expect(comments[0][:text]).to start_with("Comment hidden by")
        expect(comments[0][:reply_level]).to be 0
        expect(comments[0][:reply_to]).to eql("")
        expect(comments[0][:is_deleted]).to be true
        # Check reply comment
        expect(comments[0][:id]).not_to be_blank
        expect(comments[1][:text]).to start_with("Comment hidden by")
        expect(comments[1][:reply_level]).to be 1
        expect(comments[1][:reply_to]).to eql(comments[0][:id])
        expect(comments[0][:is_deleted]).to be true
      end

      it "handles comments to max depth" do
        comments = @fa.submission_comments("32057717", false)
        expect(comments).to be_instance_of Array
        expect(comments.length).to be 22
        last_comment_id = ""
        level = 0
        comments.each do |comment|
          expect(comment[:id]).to match(/[0-9]+/)
          expect(comment).to have_valid_profile_link
          expect(comment[:avatar]).to be_valid_avatar_for_user(comment[:profile_name])
          expect(comment[:posted]).to be_valid_date_and_match_iso(comment[:posted_at])
          expect(comment[:text]).not_to be_blank
          expect(comment[:reply_to]).to eql(last_comment_id)
          expect(comment[:reply_level]).to be level

          if level <= 19
            last_comment_id = comment[:id]
            level += 1
          end
        end
      end

      it "handles edited comments" do
        comments = @fa.submission_comments("32057705", false)
        expect(comments).to be_instance_of Array
        expect(comments.length).to be 2
        # Check edited comment
        expect(comments[0][:id]).to match(/[0-9]+/)
        expect(comments[0]).to have_valid_profile_link
        expect(comments[0][:avatar]).to be_valid_avatar_for_user(comments[0][:profile_name])
        expect(comments[0][:posted]).to be_valid_date_and_match_iso(comments[0][:posted_at])
        expect(comments[0][:text]).not_to be_blank
        expect(comments[0][:reply_to]).to be_blank
        expect(comments[0][:reply_level]).to be 0
        # Check non-edited comment
        expect(comments[1][:id]).to match(/[0-9]+/)
        expect(comments[1]).to have_valid_profile_link
        expect(comments[1][:avatar]).to be_valid_avatar_for_user(comments[1][:profile_name])
        expect(comments[1][:posted]).to be_valid_date_and_match_iso(comments[1][:posted_at])
        expect(comments[1][:text]).not_to be_blank
        expect(comments[1][:reply_to]).to be_blank
        expect(comments[1][:reply_level]).to be 0
      end

      it "handles reply chain, followed by reply to base comment" do
        comments = @fa.submission_comments("32058026", false)
        expect(comments).to be_instance_of Array
        expect(comments.length).to be 4
        # Check base comment
        expect(comments[0][:id]).to match(/[0-9]+/)
        expect(comments[0][:text]).to eql("Base comment")
        expect(comments[0][:reply_to]).to eql("")
        expect(comments[0][:reply_level]).to be 0
        # Check first reply
        expect(comments[1][:id]).to match(/[0-9]+/)
        expect(comments[1][:text]).to eql("First reply")
        expect(comments[1][:reply_to]).to eql(comments[0][:id])
        expect(comments[1][:reply_level]).to be 1
        # Check deep reply
        expect(comments[2][:id]).to match(/[0-9]+/)
        expect(comments[2][:text]).to eql("Deep reply")
        expect(comments[2][:reply_to]).to eql(comments[1][:id])
        expect(comments[2][:reply_level]).to be 2
        # Check second reply
        expect(comments[3][:id]).to match(/[0-9]+/)
        expect(comments[3][:text]).to eql("Second base reply")
        expect(comments[3][:reply_to]).to eql(comments[0][:id])
        expect(comments[3][:reply_level]).to be 1
      end
    end

    context "on a journal" do
      it "displays a valid list of top level comments" do
        journal_id = "6704315"
        comments = @fa.journal_comments(journal_id, false)
        expect(comments).to be_instance_of Array
        expect(comments).not_to be_empty
        comments.each do |comment|
          expect(comment[:id]).to match(/[0-9]+/)
          expect(comment).to have_valid_profile_link
          expect(comment[:avatar]).to be_valid_avatar_for_user(comment[:profile_name])
          expect(comment[:posted]).to be_valid_date_and_match_iso(comment[:posted_at])
          expect(comment[:text]).not_to be_blank
          expect(comment[:reply_to]).to be_blank
          expect(comment[:reply_level]).to be 0
        end
      end

      it "handles empty comments section" do
        journal_id = "6704317"
        comments = @fa.journal_comments(journal_id, false)
        expect(comments).to be_instance_of Array
        expect(comments).to be_empty
      end

      it "hides deleted comments by default" do
        journal_id = "6704520"
        comments = @fa.journal_comments(journal_id, false)
        expect(comments).to be_instance_of Array
        expect(comments.length).to be 1
        expect(comments[0][:text]).to eql("Non-deleted comment")
      end

      it "handles comments deleted by author when specified" do
        journal_id = "6704520"
        comments = @fa.journal_comments(journal_id, true)
        expect(comments).to be_instance_of Array
        expect(comments.length).to be 2
        expect(comments[0]).to have_key(:id)
        expect(comments[0][:text]).to eql("Non-deleted comment")
        expect(comments[0][:is_deleted]).to be false
        expect(comments[1]).to have_key(:id)
        expect(comments[1][:text]).to eql("Comment hidden by its owner")
        expect(comments[1][:is_deleted]).to be true
      end

      it "handles comments deleted by journal owner when specified" do
        journal_id = "9185920"
        comments_not_deleted = @fa.journal_comments(journal_id, false)
        expect(comments_not_deleted).to be_instance_of Array
        expect(comments_not_deleted).to be_empty
        # Ensure comments appear when viewing deleted
        comments = @fa.journal_comments(journal_id, true)
        expect(comments).to be_instance_of Array
        expect(comments.length).to be 1
        expect(comments[0]).to have_key(:id)
        expect(comments[0][:text]).to eql("Comment hidden by  the page owner")
        expect(comments[0][:is_deleted]).to be true
      end

      it "fails when given non-existent journal" do
        expect { @fa.journal_comments("6894929", false) }.to raise_error(FASystemError)
      end

      it "correctly parses replies and reply levels" do
        comments = @fa.journal_comments("6894788", false)
        # Check first comment
        expect(comments[0][:id]).not_to be_blank
        expect(comments[0][:profile_name]).to eql(TEST_USER_3)
        expect(comments[0]).to have_valid_profile_link
        expect(comments[0][:avatar]).to be_valid_avatar_for_user(comments[0][:profile_name])
        expect(comments[0][:posted]).to be_valid_date_and_match_iso(comments[0][:posted_at])
        expect(comments[0][:text]).to eql("Base journal comment")
        expect(comments[0][:reply_to]).to be_blank
        expect(comments[0][:reply_level]).to be 0
        # Check second comments
        expect(comments[1][:id]).not_to be_blank
        expect(comments[1][:profile_name]).to eql(TEST_USER_3)
        expect(comments[1]).to have_valid_profile_link
        expect(comments[1][:avatar]).to be_valid_avatar_for_user(comments[1][:profile_name])
        expect(comments[1][:posted]).to be_valid_date_and_match_iso(comments[1][:posted_at])
        expect(comments[1][:text]).to eql("Reply to journal comment")
        expect(comments[1][:reply_to]).not_to be_blank
        expect(comments[1][:reply_to]).to eql(comments[0][:id])
        expect(comments[1][:reply_level]).to be 1
        # Check third comments
        expect(comments[2][:id]).not_to be_blank
        expect(comments[2][:profile_name]).to eql("fafeed-no-watchers")
        expect(comments[2]).to have_valid_profile_link
        expect(comments[2][:avatar]).to be_valid_avatar_for_user(comments[2][:profile_name])
        expect(comments[2][:posted]).to be_valid_date_and_match_iso(comments[2][:posted_at])
        expect(comments[2][:text]).to eql("Another reply on this journal")
        expect(comments[2][:reply_to]).not_to be_blank
        expect(comments[2][:reply_to]).to eql(comments[1][:id])
        expect(comments[2][:reply_level]).to be 2
      end

      it "handles replies to deleted comments" do
        comments = @fa.journal_comments("9187935", true)
        expect(comments).to be_instance_of Array
        expect(comments.length).to be 2
        # Check hidden comment
        expect(comments[0][:id]).not_to be_blank
        expect(comments[0][:text]).to start_with("Comment hidden by")
        expect(comments[0][:reply_to]).to eql("")
        expect(comments[0][:reply_level]).to be 0
        expect(comments[0][:is_deleted]).to be true
        # Check reply comment
        expect(comments[1][:id]).not_to be_blank
        expect(comments[1][:text]).not_to start_with("Comment hidden by")
        expect(comments[1]).to have_key(:profile_name)
        expect(comments[1][:reply_level]).to be 1
        expect(comments[1][:reply_to]).to eql(comments[0][:id])
        expect(comments[1][:is_deleted]).to be false
      end

      it "handles replies to hidden deleted comments" do
        comments = @fa.journal_comments("9187935", false)
        expect(comments).to be_instance_of Array
        expect(comments.length).to be 1
        # Reply comment should be only comment
        expect(comments[0][:id]).not_to be_blank
        expect(comments[0][:text]).not_to start_with("Comment hidden by")
        expect(comments[0]).to have_key(:profile_name)
        expect(comments[0][:reply_level]).to be 1
        expect(comments[0][:reply_to]).not_to be_blank
      end

      it "handles 2 replies to the same comment" do
        comments = @fa.journal_comments("9187933", false)
        expect(comments).to be_instance_of Array
        expect(comments.length).to be 3
        # Base comment
        expect(comments[0][:id]).not_to be_blank
        expect(comments[0][:text]).to eql("Base comment")
        expect(comments[0][:reply_level]).to be 0
        expect(comments[0][:reply_to]).to eql("")
        # First reply
        expect(comments[1][:id]).not_to be_blank
        expect(comments[1][:text]).to eql("First reply")
        expect(comments[1][:reply_level]).to be 1
        expect(comments[1][:reply_to]).to eql(comments[0][:id])
        # Second reply
        expect(comments[2][:id]).not_to be_blank
        expect(comments[2][:text]).to eql("Second reply")
        expect(comments[2][:reply_level]).to be 1
        expect(comments[2][:reply_to]).to eql(comments[0][:id])
      end

      it "handles deleted replies to deleted comments" do
        comments = @fa.journal_comments("9187934", true)
        expect(comments).to be_instance_of Array
        expect(comments.length).to be 2
        # Check hidden comment
        expect(comments[0]).to have_key(:id)
        expect(comments[0][:text]).to start_with("Comment hidden by")
        expect(comments[0][:reply_level]).to be 0
        expect(comments[0][:reply_to]).to eql("")
        expect(comments[0][:is_deleted]).to be true
        # Check reply comment
        expect(comments[1]).to have_key(:id)
        expect(comments[1][:text]).to start_with("Comment hidden by")
        expect(comments[1][:reply_level]).to be 1
        expect(comments[1][:reply_to]).to eql(comments[0][:id])
        expect(comments[1][:is_deleted]).to be true
      end

      it "handles comments to max depth" do
        comments = @fa.submission_comments("32057717", false)
        expect(comments).to be_instance_of Array
        expect(comments.length).to be 22
        last_comment_id = ""
        level = 0
        comments.each do |comment|
          expect(comment[:id]).to match(/[0-9]+/)
          expect(comment).to have_valid_profile_link
          expect(comment[:avatar]).to be_valid_avatar_for_user(comment[:profile_name])
          expect(comment[:posted]).to be_valid_date_and_match_iso(comment[:posted_at])
          expect(comment[:text]).not_to be_blank
          expect(comment[:reply_to]).to eql(last_comment_id)
          expect(comment[:reply_level]).to be level

          if level <= 19
            last_comment_id = comment[:id]
            level += 1
          end
        end
      end

      it "handles edited comments" do
        comments = @fa.journal_comments("9187948", false)
        expect(comments).to be_instance_of Array
        expect(comments.length).to be 2
        # Check edited comment
        expect(comments[0][:id]).to match(/[0-9]+/)
        expect(comments[0]).to have_valid_profile_link
        expect(comments[0][:avatar]).to be_valid_avatar_for_user(comments[0][:profile_name])
        expect(comments[0][:posted]).to be_valid_date_and_match_iso(comments[0][:posted_at])
        expect(comments[0][:text]).not_to be_blank
        expect(comments[0][:reply_to]).to be_blank
        expect(comments[0][:reply_level]).to be 0
        # Check non-edited comment
        expect(comments[1][:id]).to match(/[0-9]+/)
        expect(comments[1]).to have_valid_profile_link
        expect(comments[1][:avatar]).to be_valid_avatar_for_user(comments[1][:profile_name])
        expect(comments[1][:posted]).to be_valid_date_and_match_iso(comments[1][:posted_at])
        expect(comments[1][:text]).not_to be_blank
        expect(comments[1][:reply_to]).to be_blank
        expect(comments[1][:reply_level]).to be 0
      end

      it "handles reply chain, followed by reply to base comment" do
        comments = @fa.journal_comments("9187949", false)
        expect(comments).to be_instance_of Array
        expect(comments.length).to be 4
        # Check base comment
        expect(comments[0][:id]).to match(/[0-9]+/)
        expect(comments[0][:text]).to eql("Base comment")
        expect(comments[0][:reply_to]).to eql("")
        expect(comments[0][:reply_level]).to be 0
        # Check first reply
        expect(comments[1][:id]).to match(/[0-9]+/)
        expect(comments[1][:text]).to eql("First reply")
        expect(comments[1][:reply_to]).to eql(comments[0][:id])
        expect(comments[1][:reply_level]).to be 1
        # Check deep reply
        expect(comments[2][:id]).to match(/[0-9]+/)
        expect(comments[2][:text]).to eql("Deep reply")
        expect(comments[2][:reply_to]).to eql(comments[1][:id])
        expect(comments[2][:reply_level]).to be 2
        # Check second reply
        expect(comments[3][:id]).to match(/[0-9]+/)
        expect(comments[3][:text]).to eql("Second base reply")
        expect(comments[3][:reply_to]).to eql(comments[0][:id])
        expect(comments[3][:reply_level]).to be 1
      end
    end
  end

  context "when reading new submission notifications" do
    it "will correctly parse current user" do
      @fa.login_cookie = COOKIE_TEST_USER_2
      new_subs = @fa.new_submissions(nil)
      expect(new_subs[:current_user][:name]).to eql(TEST_USER_2)
      expect(new_subs[:current_user]).to have_valid_profile_link
    end

    it "should handle zero notifications" do
      @fa.login_cookie = COOKIE_TEST_USER_2
      new_subs = @fa.new_submissions(nil)
      expect(new_subs[:new_submissions]).to be_instance_of Array
      expect(new_subs[:new_submissions]).to be_empty
    end

    it "should hide nsfw submissions if sfw=1 is specified" do
      @fa.login_cookie = COOKIE_TEST_USER_3
      new_subs = @fa.new_submissions(nil)

      @fa.safe_for_work = true
      new_safe_subs = @fa.new_submissions(nil)

      expect(new_safe_subs[:new_submissions].length).to be < new_subs[:new_submissions].length
    end

    it "returns a valid list of new submission notifications" do
      @fa.login_cookie = COOKIE_TEST_USER_3
      new_subs = @fa.new_submissions(nil)
      expect(new_subs[:new_submissions]).to be_instance_of Array
      expect(new_subs[:new_submissions]).not_to be_empty
      new_subs[:new_submissions].each do |sub|
        expect(sub).to be_valid_submission
      end
    end

    it "handles paging correctly" do
      @fa.login_cookie = COOKIE_TEST_USER_3
      all_subs = @fa.new_submissions(nil)[:new_submissions]
      expect(all_subs).to be_instance_of Array
      expect(all_subs).not_to be_empty

      second_sub_id = all_subs[1][:id]
      all_from_second = @fa.new_submissions(second_sub_id)[:new_submissions]
      expect(all_from_second).to be_instance_of Array
      expect(all_from_second).not_to be_empty

      all_after_second = @fa.new_submissions(second_sub_id.to_i - 1)[:new_submissions]
      expect(all_after_second).to be_instance_of Array
      expect(all_after_second).not_to be_empty

      expect(all_from_second.length).to be(all_subs.length - 1)
      expect(all_from_second[0][:id]).to eql(all_subs[1][:id])
      expect(all_after_second.length).to be(all_subs.length - 2)
      expect(all_after_second[0][:id]).to eql(all_subs[2][:id])
    end
  end

  context "when reading notifications" do
    it "will correctly parse current user" do
      @fa.login_cookie = COOKIE_TEST_USER_2
      notifications = @fa.notifications(false)
      expect(notifications[:current_user][:name]).to eql(TEST_USER_2)
      expect(notifications[:current_user]).to have_valid_profile_link
    end

    it "should not return anything unless login cookie is given" do
      @fa.login_cookie = nil
      expect { @fa.notifications(false) }.to raise_error(FALoginError)
    end

    it "should display non-zero notification totals" do
      @fa.login_cookie = COOKIE_TEST_USER_2
      notifications = @fa.notifications(false)
      expect(notifications).to have_key(:notification_counts)
      counts = notifications[:notification_counts]
      expect(counts).to have_key(:submissions)
      expect(counts).to have_key(:comments)
      expect(counts).to have_key(:journals)
      expect(counts).to have_key(:favorites)
      expect(counts).to have_key(:watchers)
      expect(counts).to have_key(:notes)
      expect(counts).to have_key(:trouble_tickets)

      expect(counts[:submissions]).to be >= 0
      expect(counts[:comments]).to be.positive?
      expect(counts[:journals]).to be >= 0
      expect(counts[:favorites]).to be.positive?
      expect(counts[:watchers]).to be.positive?
      expect(counts[:notes]).to be.positive?
      expect(counts[:trouble_tickets]).to be >= 0
    end

    it "should contain all 6 types of notifications" do
      @fa.login_cookie = COOKIE_TEST_USER_2
      notifications = @fa.notifications(false)
      expect(notifications).to have_key(:new_watches)
      expect(notifications).to have_key(:new_submission_comments)
      expect(notifications).to have_key(:new_journal_comments)
      expect(notifications).to have_key(:new_shouts)
      expect(notifications).to have_key(:new_favorites)
      expect(notifications).to have_key(:new_journals)
    end

    context "watcher notifications" do
      it "should handle zero new watchers" do
        @fa.login_cookie = COOKIE_TEST_USER_3
        watchers = @fa.notifications(false)[:new_watches]
        expect(watchers).to be_instance_of Array
        expect(watchers).to be_empty
      end

      it "returns a list of new watcher notifications" do
        @fa.login_cookie = COOKIE_TEST_USER_2
        watchers = @fa.notifications(false)[:new_watches]
        expect(watchers).to be_instance_of Array
        expect(watchers).not_to be_empty
        watchers.each do |watcher|
          expect(watcher[:watch_id]).to match(/[0-9]+/)
          expect(watcher).to have_valid_profile_link
          expect(watcher[:avatar]).to be_valid_avatar_for_user(watcher[:profile_name])
          expect(watcher[:posted]).to be_valid_date_and_match_iso(watcher[:posted_at])
        end
      end

      it "should hide deleted watcher notifications by default" do
        @fa.login_cookie = COOKIE_TEST_USER_2
        watchers = @fa.notifications(false)[:new_watches]
        expect(watchers).to be_instance_of Array
        expect(watchers).not_to be_empty
        expect(watchers.length).to be 1
      end

      it "should display deleted watcher notifications when specified and hide otherwise" do
        skip "Skipped: Looks like deleted watcher notifications don't display anymore"
        @fa.login_cookie = COOKIE_TEST_USER_2
        watchers = @fa.notifications(false)[:new_watches]
        expect(watchers).to be_instance_of Array
        expect(watchers).not_to be_empty

        watchers_deleted = @fa.notifications(true)[:new_watches]
        expect(watchers_deleted).to be_instance_of Array
        expect(watchers_deleted).not_to be_empty

        expect(watchers_deleted.length).to be > watchers.length

        deleted_watch = watchers_deleted[-1]
        expect(deleted_watch[:watch_id]).to eql("")
        expect(deleted_watch[:name]).to eql("Removed by the user")
        expect(deleted_watch[:profile]).to eql("")
        expect(deleted_watch[:profile_name]).to eql("")
        expect(deleted_watch[:avatar]).to eql("I forgot the link.")
        expect(deleted_watch[:posted]).to eql("")
        expect(deleted_watch[:posted_at]).to eql("")
      end
    end

    context "submission comment notifications" do
      it "should handle zero submission comment notifications" do
        @fa.login_cookie = COOKIE_TEST_USER_NO_NOTIFICATIONS
        notifications = @fa.notifications(false)[:new_submission_comments]
        expect(notifications).to be_instance_of Array
        expect(notifications).to be_empty
      end

      it "returns a list of new submission comment notifications" do
        @fa.login_cookie = COOKIE_TEST_USER_2
        notifications = @fa.notifications(false)[:new_submission_comments]
        expect(notifications).to be_instance_of Array
        expect(notifications).not_to be_empty
        notifications.each do |comment_notification|
          expect(comment_notification[:comment_id]).to match(/[0-9]+/)
          expect(comment_notification).to have_valid_profile_link
          expect(comment_notification[:is_reply]).to be_in([true, false])
          expect(comment_notification[:your_submission]).to be_in([true, false])
          expect(comment_notification[:their_submission]).to be_in([true, false])
          # Can't be both yours and theirs
          expect(comment_notification[:your_submission] && comment_notification[:their_submission]).to be false
          expect(comment_notification[:submission_id]).to match(/[0-9]+/)
          expect(comment_notification[:title]).not_to be_blank
          expect(comment_notification[:posted]).to be_valid_date_and_match_iso(comment_notification[:posted_at])
        end
      end

      it "correctly parses base level comments to your submissions" do
        @fa.login_cookie = COOKIE_TEST_USER_2
        notifications = @fa.notifications(false)[:new_submission_comments]
        expect(notifications).to be_instance_of Array
        expect(notifications).not_to be_empty

        found_comment = false

        notifications.each do |comment_notification|
          if !comment_notification[:is_reply] &&
             comment_notification[:your_submission] &&
             !comment_notification[:their_submission]
            found_comment = true
          end
        end

        expect(found_comment).to be true
      end

      it "correctly parses replies to your comments on your submissions" do
        @fa.login_cookie = COOKIE_TEST_USER_2
        notifications = @fa.notifications(false)[:new_submission_comments]
        expect(notifications).to be_instance_of Array
        expect(notifications).not_to be_empty

        found_comment = false

        notifications.each do |comment_notification|
          if comment_notification[:is_reply] &&
             comment_notification[:your_submission] &&
             !comment_notification[:their_submission]
            found_comment = true
          end
        end

        expect(found_comment).to be true
      end

      it "correctly parses replies to your comments on their submissions" do
        @fa.login_cookie = COOKIE_TEST_USER_2
        notifications = @fa.notifications(false)[:new_submission_comments]
        expect(notifications).to be_instance_of Array
        expect(notifications).not_to be_empty

        found_comment = false

        notifications.each do |comment_notification|
          if comment_notification[:is_reply] &&
             !comment_notification[:your_submission] &&
             comment_notification[:their_submission]
            found_comment = true
          end
        end

        expect(found_comment).to be true
      end

      it "correctly parses replies to your comments on someone else's submissions" do
        @fa.login_cookie = COOKIE_TEST_USER_2
        notifications = @fa.notifications(false)[:new_submission_comments]
        expect(notifications).to be_instance_of Array
        expect(notifications).not_to be_empty

        found_comment = false

        notifications.each do |comment_notification|
          if comment_notification[:is_reply] &&
             !comment_notification[:your_submission] &&
             !comment_notification[:their_submission]
            found_comment = true
          end
        end

        expect(found_comment).to be true
      end

      it "displays deleted submission comment notifications when specified and hide otherwise" do
        @fa.login_cookie = COOKIE_TEST_USER_2
        notifications = @fa.notifications(false)[:new_submission_comments]
        expect(notifications).to be_instance_of Array
        expect(notifications).not_to be_empty

        notifications_include = @fa.notifications(true)[:new_submission_comments]
        expect(notifications_include).to be_instance_of Array
        expect(notifications_include).not_to be_empty

        expect(notifications_include.length).to be > notifications.length

        deleted = notifications_include - notifications

        deleted.each do |deleted_comment|
          expect(deleted_comment[:comment_id]).to eql("")
          expect(deleted_comment[:name]).to eql("Comment or the submission it was left on has been deleted")
          expect(deleted_comment[:profile]).to eql("")
          expect(deleted_comment[:profile_name]).to eql("")
          expect(deleted_comment[:is_reply]).to be false
          expect(deleted_comment[:your_submission]).to be false
          expect(deleted_comment[:their_submission]).to be false
          expect(deleted_comment[:submission_id]).to eql("")
          expect(deleted_comment[:title]).to eql("Comment or the submission it was left on has been deleted")
          expect(deleted_comment[:posted]).to eql("")
          expect(deleted_comment[:posted_at]).to eql("")
        end
      end
    end

    context "journal comment notifications" do
      it "should handle zero journal comment notifications" do
        @fa.login_cookie = COOKIE_TEST_USER_NO_NOTIFICATIONS
        notifications = @fa.notifications(false)[:new_journal_comments]
        expect(notifications).to be_instance_of Array
        expect(notifications).to be_empty
      end

      it "returns a list of new journal comment notifications" do
        @fa.login_cookie = COOKIE_TEST_USER_2
        notifications = @fa.notifications(false)[:new_journal_comments]
        expect(notifications).to be_instance_of Array
        expect(notifications).not_to be_empty
        notifications.each do |comment_notification|
          expect(comment_notification[:comment_id]).to match(/[0-9]+/)
          expect(comment_notification).to have_valid_profile_link
          expect(comment_notification[:is_reply]).to be_in([true, false])
          expect(comment_notification[:your_journal]).to be_in([true, false])
          expect(comment_notification[:their_journal]).to be_in([true, false])
          expect(comment_notification[:your_journal] && comment_notification[:their_journal]).to be false
          expect(comment_notification[:journal_id]).to match(/[0-9]+/)
          expect(comment_notification[:title]).not_to be_blank
          expect(comment_notification[:posted]).to be_valid_date_and_match_iso(comment_notification[:posted_at])
        end
      end

      it "correctly parses base level comments to your journals" do
        @fa.login_cookie = COOKIE_TEST_USER_2
        notifications = @fa.notifications(false)[:new_journal_comments]
        expect(notifications).to be_instance_of Array
        expect(notifications).not_to be_empty

        found_comment = false

        notifications.each do |comment_notification|
          if !comment_notification[:is_reply] &&
             comment_notification[:your_journal] &&
             !comment_notification[:their_journal]
            found_comment = true
          end
        end

        expect(found_comment).to be true
      end

      it "correctly parses replies to your comments on your journals" do
        @fa.login_cookie = COOKIE_TEST_USER_2
        notifications = @fa.notifications(false)[:new_journal_comments]
        expect(notifications).to be_instance_of Array
        expect(notifications).not_to be_empty

        found_comment = false

        notifications.each do |comment_notification|
          if comment_notification[:is_reply] &&
             comment_notification[:your_journal] &&
             !comment_notification[:their_journal]
            found_comment = true
          end
        end

        expect(found_comment).to be true
      end

      it "correctly parses replies to your comments on their journals" do
        @fa.login_cookie = COOKIE_TEST_USER_2
        notifications = @fa.notifications(false)[:new_journal_comments]
        expect(notifications).to be_instance_of Array
        expect(notifications).not_to be_empty

        found_comment = false

        notifications.each do |comment_notification|
          if comment_notification[:is_reply] &&
             !comment_notification[:your_journal] &&
             comment_notification[:their_journal]
            found_comment = true
          end
        end

        expect(found_comment).to be true
      end

      it "correctly parses replies to your comments on someone else's journals" do
        @fa.login_cookie = COOKIE_TEST_USER_2
        notifications = @fa.notifications(false)[:new_journal_comments]
        expect(notifications).to be_instance_of Array
        expect(notifications).not_to be_empty

        found_comment = false

        notifications.each do |comment_notification|
          if comment_notification[:is_reply] &&
             !comment_notification[:your_journal] &&
             !comment_notification[:their_journal]
            found_comment = true
          end
        end

        expect(found_comment).to be true
      end

      it "displays deleted journal comment notifications when specified and hide otherwise" do
        @fa.login_cookie = COOKIE_TEST_USER_2
        notifications = @fa.notifications(false)[:new_journal_comments]
        expect(notifications).to be_instance_of Array
        expect(notifications).not_to be_empty

        notifications_include = @fa.notifications(true)[:new_journal_comments]
        expect(notifications_include).to be_instance_of Array
        expect(notifications_include).not_to be_empty

        expect(notifications_include.length).to be > notifications.length

        deleted = notifications_include - notifications

        deleted.each do |deleted_comment|
          expect(deleted_comment[:comment_id]).to eql("")
          expect(deleted_comment[:name]).to eql("Comment or the journal it was left on has been deleted")
          expect(deleted_comment[:profile]).to eql("")
          expect(deleted_comment[:profile_name]).to eql("")
          expect(deleted_comment[:is_reply]).to be false
          expect(deleted_comment[:your_journal]).to be false
          expect(deleted_comment[:their_journal]).to be false
          expect(deleted_comment[:journal_id]).to eql("")
          expect(deleted_comment[:title]).to eql("Comment or the journal it was left on has been deleted")
          expect(deleted_comment[:posted]).to eql("")
          expect(deleted_comment[:posted_at]).to eql("")
        end
      end
    end

    context "shout notifications" do
      it "should handle zero shout notifications" do
        @fa.login_cookie = COOKIE_TEST_USER_NO_NOTIFICATIONS
        notifications = @fa.notifications(false)[:new_shouts]
        expect(notifications).to be_instance_of Array
        expect(notifications).to be_empty
      end

      it "returns a list of new shout notifications" do
        @fa.login_cookie = COOKIE_TEST_USER_2
        notifications = @fa.notifications(false)[:new_shouts]
        expect(notifications).to be_instance_of Array
        expect(notifications).not_to be_empty

        notifications.each do |new_shout|
          expect(new_shout[:shout_id]).to match(/[0-9]+/)
          expect(new_shout).to have_valid_profile_link
          expect(new_shout[:posted]).to be_valid_date_and_match_iso(new_shout[:posted_at])
        end
      end

      it "displays deleted shout notifications when specified and hides otherwise" do
        @fa.login_cookie = COOKIE_TEST_USER_2
        notifications = @fa.notifications(false)[:new_shouts]
        expect(notifications).to be_instance_of Array
        expect(notifications).not_to be_empty

        notifications_include = @fa.notifications(true)[:new_shouts]
        expect(notifications_include).to be_instance_of Array
        expect(notifications_include).not_to be_empty

        expect(notifications_include.length).to be > notifications.length

        deleted = notifications_include - notifications

        deleted.each do |deleted_shout|
          expect(deleted_shout[:shout_id]).to eql("")
          expect(deleted_shout[:name]).to eql("Shout has been removed from your page")
          expect(deleted_shout[:profile]).to eql("")
          expect(deleted_shout[:profile_name]).to eql("")
          expect(deleted_shout[:posted]).to eql("")
          expect(deleted_shout[:posted_at]).to eql("")
        end
      end
    end

    context "favourite notifications" do
      it "should handle zero favourite notifications" do
        @fa.login_cookie = COOKIE_TEST_USER_NO_NOTIFICATIONS
        notifications = @fa.notifications(false)[:new_favorites]
        expect(notifications).to be_instance_of Array
        expect(notifications).to be_empty
      end

      it "returns a list of new favourite notifications" do
        @fa.login_cookie = COOKIE_TEST_USER_2
        notifications = @fa.notifications(false)[:new_favorites]
        expect(notifications).to be_instance_of Array
        expect(notifications).not_to be_empty

        notifications.each do |new_fav|
          expect(new_fav[:favorite_notification_id]).to match(/[0-9]+/)
          expect(new_fav).to have_valid_profile_link
          expect(new_fav[:submission_id]).to match(/[0-9]+/)
          expect(new_fav[:submission_name]).not_to be_blank
          expect(new_fav[:posted]).to be_valid_date_and_match_iso(new_fav[:posted_at])
        end
      end

      it "displays deleted favourite notifications when specified and hides otherwise" do
        skip "Skipped: Looks like deleted favourite notifications don't display anymore"
        @fa.login_cookie = COOKIE_TEST_USER_2
        notifications = @fa.notifications(false)[:new_favorites]
        expect(notifications).to be_instance_of Array
        expect(notifications).not_to be_empty

        notifications_include = @fa.notifications(true)[:new_favorites]
        expect(notifications_include).to be_instance_of Array
        expect(notifications_include).not_to be_empty

        expect(notifications_include.length).to be > notifications.length

        deleted = notifications_include - notifications

        deleted.each do |deleted_fav|
          expect(deleted_fav[:favorite_notification_id]).to eql("")
          expect(deleted_fav[:name]).to eql("The favorite this notification was for has since been removed by the user")
          expect(deleted_fav[:profile]).to eql("")
          expect(deleted_fav[:profile_name]).to eql("")
          expect(deleted_fav[:submission_id]).to eql("")
          expect(deleted_fav[:submission_name]).to eql("The favorite this notification was for has since been removed by the user")
          expect(deleted_fav[:posted]).to eql("")
          expect(deleted_fav[:posted_at]).to eql("")
        end
      end
    end

    context "journal notifications" do
      # TODO: add a test for deleted journals. (Only available if user deactivates account)
      it "should handle zero new journals" do
        @fa.login_cookie = COOKIE_TEST_USER_NO_NOTIFICATIONS
        notifications = @fa.notifications(false)[:new_journals]
        expect(notifications).to be_instance_of Array
        expect(notifications).to be_empty
      end

      it "returns a list of new journal notifications" do
        @fa.login_cookie = COOKIE_TEST_USER_3
        notifications = @fa.notifications(false)[:new_journals]
        expect(notifications).to be_instance_of Array
        expect(notifications).not_to be_empty

        notifications.each do |new_journal|
          expect(new_journal[:journal_id]).to match(/[0-9]+/)
          expect(new_journal[:title]).not_to be_blank
          expect(new_journal).to have_valid_profile_link
          expect(new_journal[:posted]).to be_valid_date_and_match_iso(new_journal[:posted_at])
        end
      end
    end
  end

  context "when posting a new journal" do
    it "requires a login cookie" do
      @fa.login_cookie = nil
      expect { @fa.submit_journal("Do not post", "This journal should fail to post") }.to raise_error(FALoginError)
    end

    it "fails if not given title" do
      expect { @fa.submit_journal(nil, "No title journal") }.to raise_error(FAFormError)
    end

    it "fails if not given description" do
      expect { @fa.submit_journal("Title, no desc", nil) }.to raise_error(FAFormError)
    end

    it "can post a new journal entry" do
      @fa.login_cookie = COOKIE_TEST_USER_JOURNAL_DUMP
      magic_key = (0...5).map { ("a".."z").to_a[rand(26)] }.join
      long_magic_key = (0...50).map { ("a".."z").to_a[rand(26)] }.join
      journal_title = "Automatically generated title - #{magic_key}"
      journal_description = "Hello, this is an automatically generated journal.\n Magic key: #{long_magic_key}"

      journal_resp = @fa.submit_journal(journal_title, journal_description)

      expect(journal_resp[:url]).to match(%r{https://www.furaffinity.net/journal/[0-9]+/})

      # Get journal listing, ensure latest is this one
      journals = @fa.journals(TEST_USER_JOURNAL_DUMP, 1)
      expect(journals[0][:title]).to eql(journal_title)
      expect(journals[0][:description]).to eql(journal_description.gsub("\n", "<br>\n"))
      expect(journal_resp[:url]).to eql("https://www.furaffinity.net/journal/#{journals[0][:id]}/")
    end
  end

  context "when viewing notes" do
    context "folders" do
      it "can list inbox" do
        @fa.login_cookie = COOKIE_TEST_USER_2
        notes = @fa.notes("inbox")

        expect(notes).not_to be_empty

        notes.map do |note|
          expect(note[:note_id]).to be_instance_of Integer
          expect(note[:note_id]).not_to be_blank
          expect(note[:subject]).to be_instance_of String
          expect(note[:subject]).not_to be_blank
          expect(note[:is_inbound]).to eql(true)
          expect(note[:is_read]).to be_in([true, false])
          expect(note[:profile]).not_to eql(TEST_USER_2)
          expect(note).to have_valid_profile_link
          expect(note[:posted]).to be_valid_date_and_match_iso(note[:posted_at])
        end
      end

      it "can list unread, which contains all unread notes from inbox" do
        @fa.login_cookie = COOKIE_TEST_USER_2
        unread_notes = @fa.notes("unread")
        inbox_notes = @fa.notes("inbox")

        expect(unread_notes).not_to be_empty

        unread_notes.map do |note|
          expect(note[:is_read]).to eql(false)
        end

        unread_note_ids = unread_notes.map { |n| n[:note_id] }
        inbox_note_ids = inbox_notes.reject { |n| n[:is_read] }.map { |n| n[:note_id] }

        inbox_note_ids.map do |note_id|
          expect(note_id).to be_in(unread_note_ids)
        end
      end

      it "can list outbox and handle unread outbound notes" do
        @fa.login_cookie = COOKIE_TEST_USER_2
        notes = @fa.notes("outbox")

        expect(notes).not_to be_empty

        notes.map do |note|
          expect(note[:note_id]).to be_instance_of Integer
          expect(note[:note_id]).not_to be_blank
          expect(note[:subject]).to be_instance_of String
          expect(note[:subject]).not_to be_blank
          expect(note[:is_inbound]).to eql(false)
          expect(note[:is_read]).to be_in([true, false])
          expect(note[:profile]).not_to eql(TEST_USER_2)
          expect(note).to have_valid_profile_link
          expect(note[:posted]).to be_valid_date_and_match_iso(note[:posted_at])
        end
      end

      it "can list other folders" do
        @fa.login_cookie = COOKIE_TEST_USER_2
        %w[high medium low archive trash].map do |folder|
          notes = @fa.notes(folder)

          expect(notes).not_to be_empty

          notes.map do |note|
            expect(note[:note_id]).to be_instance_of Integer
            expect(note[:note_id]).not_to be_blank
            expect(note[:subject]).to be_instance_of String
            expect(note[:subject]).not_to be_blank
            expect(note[:is_inbound]).to be_in([true, false])
            expect(note[:is_read]).to be_in([true, false])
            expect(note[:profile]).not_to eql(TEST_USER_2)
            expect(note).to have_valid_profile_link
            expect(note[:posted]).to be_valid_date_and_match_iso(note[:posted_at])
          end
        end
      end
    end

    context "individual notes" do
      it "can view a specific note" do
        @fa.login_cookie = COOKIE_TEST_USER_2
        note = @fa.note(108_710_830)

        expect(note[:note_id]).to be_instance_of Integer
        expect(note[:note_id]).not_to be_blank
        expect(note[:subject]).to be_instance_of String
        expect(note[:subject]).not_to be_blank
        expect(note[:is_inbound]).to eql(true)
        expect(note[:profile]).not_to eql(TEST_USER_2)
        expect(note).to have_valid_profile_link
        expect(note[:posted]).to be_valid_date_and_match_iso(note[:posted_at])
        expect(note[:description]).to be_instance_of String
        expect(note[:description]).not_to be_blank
        expect(note[:description_body]).to be_instance_of String
        expect(note[:description_body]).not_to be_blank
        expect(note[:description]).to start_with(note[:description_body])
        expect(note[:preceding_notes]).to be_instance_of Array
        expect(note[:preceding_notes].length).to eql(0)
      end

      it "correctly parses preceding notes" do
        @fa.login_cookie = COOKIE_TEST_USER_2
        note = @fa.note(108_710_838)

        expect(note[:note_id]).to be_instance_of Integer
        expect(note[:note_id]).not_to be_blank
        expect(note[:subject]).to be_instance_of String
        expect(note[:subject]).not_to be_blank
        expect(note[:is_inbound]).to be_in([true, false])
        expect(note[:profile]).not_to eql(TEST_USER_2)
        expect(note).to have_valid_profile_link
        expect(note[:posted]).to be_valid_date_and_match_iso(note[:posted_at])
        expect(note[:description]).to be_instance_of String
        expect(note[:description]).not_to be_blank
        expect(note[:description_body]).to be_instance_of String
        expect(note[:description_body]).not_to be_blank
        expect(note[:description]).to start_with(note[:description_body])
        expect(note[:preceding_notes]).to be_instance_of Array
        expect(note[:preceding_notes].length).to eql(1)
        expect(note[:preceding_notes][0][:description]).to be_instance_of String
        expect(note[:preceding_notes][0][:description]).not_to be_blank
        expect(note[:preceding_notes][0]).to have_valid_profile_link
        expect(note[:preceding_notes][0][:profile]).not_to eql(TEST_USER_2)
      end

      it "throws an error for an invalid note" do
        @fa.login_cookie = COOKIE_TEST_USER_2
        expect { @fa.note(108_710_839) }.to raise_error(FASystemError)
      end
    end
  end

  context "when browsing" do
    it "returns a list of submissions" do
      submissions = @fa.browse({ "page" => "1" })

      submissions.each do |submission|
        expect(submission).to be_valid_submission
      end
    end

    it "returns a second page, different to the first" do
      submissions1 = @fa.browse({ "page" => "1" })
      submissions2 = @fa.browse({ "page" => "2" })

      submissions1.each do |submission|
        expect(submission).to be_valid_submission
      end
      submissions2.each do |submission|
        expect(submission).to be_valid_submission
      end

      expect(submissions1).to be_different_results_to(submissions2)
    end

    it "defaults to 72 results" do
      submissions = @fa.browse({})

      submissions.each do |submission|
        expect(submission).to be_valid_submission
      end
      expect(submissions.length).to eql(72)
    end

    it "returns as many submissions as perpage specifies" do
      submissions24 = @fa.browse({ "perpage" => "24" })
      submissions48 = @fa.browse({ "perpage" => "48" })
      submissions72 = @fa.browse({ "perpage" => "72" })

      expect(submissions24.length).to eql(24)
      expect(submissions48.length).to eql(48)
      expect(submissions72.length).to eql(72)
    end

    it "can specify ratings to display, and honours that selection" do
      only_adult = @fa.browse({ "perpage" => 24, "rating" => "adult" })
      only_sfw_or_mature = @fa.browse({ "perpage" => 24, "rating" => "mature,general" })

      expect(only_adult).to be_different_results_to(only_sfw_or_mature)

      only_adult[0..5].each do |submission|
        full_submission = @fa.submission(submission[:id])
        expect(full_submission[:rating]).to eql("Adult")
      end

      only_sfw_or_mature[0..5].each do |submission|
        full_submission = @fa.submission(submission[:id])
        expect(full_submission[:rating]).not_to eql("Adult")
      end
    end
  end

  context "when checking FA status" do
    it "displays the usual status information" do
      status = @fa.status

      expect(status).to be_valid_status_data
    end

    it "displays status information after another page load" do
      status1 = @fa.status
      @fa.home
      status2 = @fa.status

      expect(status1).to be_valid_status_data
      expect(status2).to be_valid_status_data
    end
  end
end
