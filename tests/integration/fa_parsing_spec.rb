
require './lib/faexport'

require 'rspec'

describe 'FA parser' do
  COOKIE_DEFAULT = ENV['test_cookie']
  TEST_USER = "fafeed"
  TEST_USER_2 = "fafeed-2"
  COOKIE_TEST_USER_2 = ENV['test_cookie_user_2']
  # Specific test user cases
  TEST_USER_NOT_EXIST = "fafeed-does-not-exist"
  TEST_USER_WITH_BRACKETS = "l[i]s"
  TEST_USER_OVER_200_WATCHERS = "fender"
  TEST_USER_NO_WATCHERS = "fafeed-no-watchers"
  TEST_USER_NO_JOURNALS = TEST_USER_NO_WATCHERS
  TEST_USER_OVER_25_JOURNALS = TEST_USER_OVER_200_WATCHERS
  TEST_USER_EMPTY_GALLERIES = TEST_USER_NO_WATCHERS
  TEST_USER_2_PAGES_GALLERY = "rajii"
  TEST_USER_HIDDEN_FAVS = TEST_USER_NO_WATCHERS
  COOKIE_TEST_USER_HIDDEN_FAVS = ENV['test_cookie_hidden_favs']
  TEST_USER_2_PAGES_FAVS = TEST_USER_2_PAGES_GALLERY

  before do
    config = File.exist?('settings-test.yml') ? YAML.load_file('settings-test.yml') : {}
    @app = FAExport::Application.new(config).instance_variable_get(:@instance)
    @fa = @app.instance_variable_get(:@fa)
    @fa.login_cookie = COOKIE_DEFAULT
  end

  after do
    # Do nothing
  end

  context 'when getting home page data' do
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
        submissions.map(&method(:check_submission))
      end
    end

    it 'only returns SFW results, if specified' do
      @fa.safe_for_work = true
      home = @fa.home
      home.map do |_, submissions|
        expect(submissions).not_to be_empty
        submissions.map do |submission|
          full_submission = @fa.submission(submission[:id])
          expect(full_submission[:rating]).to eql("General")
        end
      end
    end
  end

  context 'when getting user profile' do
    it 'gives valid basic profile information' do
      profile = @fa.user(TEST_USER)
      # Check initial values
      expect(profile[:id]).to be_nil
      expect(profile[:name]).to eql(TEST_USER)
      expect(profile[:profile]).to eql("https://www.furaffinity.net/user/#{TEST_USER}/")
      expect(profile[:account_type]).to eql("Member")
      check_avatar(profile[:avatar], TEST_USER)
      expect(profile[:full_name]).not_to be_blank
      expect(profile[:artist_type]).not_to be_blank
      expect(profile[:user_title]).not_to be_blank
      expect(profile[:user_title]).to eql(profile[:artist_type])
      expect(profile[:current_mood]).to eql("accomplished")
      # Check registration date
      check_date(profile[:registered_since], profile[:registered_at])
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
      profile_with_underscores = TEST_USER_WITH_BRACKETS
      profile = @fa.user(profile_with_underscores)
      expect(profile[:name].downcase).to eql(profile_with_underscores)
    end

    it 'shows featured submission' do
      profile = @fa.user(TEST_USER_2)
      expect(profile[:featured_submission]).not_to be_nil
      check_submission profile[:featured_submission], true
    end

    it 'handles featured submission not being set' do
      profile = @fa.user(TEST_USER)
      expect(profile[:featured_submission]).to be_nil
    end

    it 'shows profile id' do
      profile = @fa.user(TEST_USER_2)
      expect(profile[:profile_id]).not_to be_nil
      check_submission profile[:profile_id], true, true
    end

    it 'handles profile id not being set' do
      profile = @fa.user(TEST_USER)
      expect(profile[:profile_id]).to be_nil
    end

    it 'shows artist information' do
      profile = @fa.user(TEST_USER_2)
      expect(profile[:artist_information]).to be_instance_of Hash
      expect(profile[:artist_information]).to have_key("Age")
      expect(profile[:artist_information]["Age"]).to eql("70")
      expect(profile[:artist_information]).to have_key("Species")
      expect(profile[:artist_information]["Species"]).to eql("Robot")
      expect(profile[:artist_information]).to have_key("Shell of Choice")
      expect(profile[:artist_information]["Shell of Choice"]).to eql("irb")
      expect(profile[:artist_information]).to have_key("Favorite Website")
      expect(profile[:artist_information]["Favorite Website"]).to start_with("<a href=")
      expect(profile[:artist_information]["Favorite Website"]).to include("https://www.ruby-lang.org")
      expect(profile[:artist_information]["Favorite Website"]).to end_with("</a>")
      expect(profile[:artist_information]).not_to have_key("Personal quote")
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
        check_profile_link(item, true)
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
        check_profile_link(item, true)
      end
    end
  end

  context 'when listing user\'s watchers/watchees' do
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

  context 'when listing a user\'s shouts' do
    it 'displays a valid list of shouts' do
      shouts = @fa.shouts(TEST_USER)
      expect(shouts).to be_instance_of Array
      shouts.each do |shout|
        expect(shout[:id]).to match(/^shout-[0-9]+$/)
        check_profile_link shout
        check_avatar(shout[:avatar], shout[:profile_name])
        check_date(shout[:posted], shout[:posted_at])
        expect(shout[:text]).to be_instance_of String
        expect(shout[:text]).not_to be_blank
      end
    end

    it 'fails when given a non-existent user' do
      expect { @fa.shouts(TEST_USER_NOT_EXIST) }.to raise_error(FASystemError)
    end

    it 'handles an empty shouts list' do
      shouts = @fa.shouts(TEST_USER_2)
      expect(shouts).to be_instance_of Array
      expect(shouts).to be_empty
    end
  end

  context 'when displaying commission information pages' do
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
        check_submission(comm[:submission], true, true)
      end
    end

    it 'fails when given a non-existent user' do
      expect { @fa.shouts(TEST_USER_NOT_EXIST) }.to raise_error(FASystemError)
    end
  end

  context 'when listing a user\'s journals' do
    it 'returns a list of journal IDs' do
      journals = @fa.journals(TEST_USER, 1)
      expect(journals).to be_instance_of Array
      expect(journals).not_to be_empty
      journals.each do |journal|
        expect(journal[:id]).to match(/^[0-9]+$/)
        expect(journal[:title]).not_to be_blank
        expect(journal[:description]).not_to be_blank
        expect(journal[:link]).to eql("https://www.furaffinity.net/journal/#{journal[:id]}/")
        check_date(journal[:posted], journal[:posted_at])
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

  context 'when viewing user galleries' do
    %w(gallery scraps favorites).each do |folder|
      it 'returns a list of valid submission' do
        submissions = @fa.submissions(TEST_USER_2, folder, {})
        expect(submissions).to be_instance_of Array
        expect(submissions).not_to be_empty
        submissions.each(&method(:check_submission))
      end

      it 'fails when given a non-existent user' do
        expect { @fa.submissions(TEST_USER_NOT_EXIST, folder, {}) }.to raise_error(FASystemError)
      end

      it 'handles an empty gallery' do
        submissions = @fa.submissions(TEST_USER_EMPTY_GALLERIES, folder, {})
        expect(submissions).to be_instance_of Array
        expect(submissions).to be_empty
      end

      it 'hides nsfw submissions if sfw is set' do
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

    context 'specifically gallery or scraps' do
      %w(gallery scraps).each do |folder|
        it 'handles paging correctly' do
          gallery1 = @fa.submissions(TEST_USER_2_PAGES_GALLERY, folder, {})
          gallery2 = @fa.submissions(TEST_USER_2_PAGES_GALLERY, folder, {page: 2})
          expect(gallery1).to be_instance_of Array
          expect(gallery2).to be_instance_of Array
          expect(gallery1).not_to eql(gallery2)
        end
      end
    end

    context 'specifically favourites' do
      it 'handles a hidden favourites list' do
        favs = @fa.submissions(TEST_USER_HIDDEN_FAVS, "favorites", {})
        expect(favs).to be_instance_of Array
        expect(favs).to be_empty
      end

      it 'displays favourites of currently logged in user even if hidden' do
        @fa.login_cookie = COOKIE_TEST_USER_HIDDEN_FAVS
        expect(@fa.login_cookie).not_to be_nil
        favs = @fa.submissions(TEST_USER_HIDDEN_FAVS, "favorites", {})
        expect(favs).to be_instance_of Array
        expect(favs).not_to be_empty
      end

      it 'uses next parameter to display submissions after a specified fav id' do
        favs = @fa.submissions(TEST_USER_2_PAGES_FAVS, "favorites", {})
        expect(favs).to be_instance_of Array
        expect(favs.length).to be 72
        # Get fav ID partially down
        fav_id = favs[58][:fav_id]
        fav_id_next = favs[59][:fav_id]
        # Get favs after that ID
        favs_next = @fa.submissions(TEST_USER_2_PAGES_FAVS, "favorites", {next: fav_id})
        expect(favs_next.length).to be > (72 - 58)
        expect(favs_next[0][:fav_id]).to eql(fav_id_next)
        favs_next.each do |fav|
          expect(fav[:fav_id]).to be < fav_id
        end
      end

      it 'uses prev parameter to display only submissions before a specified fav id' do
        favs1 = @fa.submissions(TEST_USER_2_PAGES_FAVS, "favorites", {})
        expect(favs1).to be_instance_of Array
        expect(favs1.length).to be 72
        last_fav_id = favs1[71][:fav_id]
        favs2 = @fa.submissions(TEST_USER_2_PAGES_FAVS, "favorites", {next: last_fav_id})
        # Get fav ID partially through
        overlap_fav_id = favs2[5][:fav_id]
        favs_overlap = @fa.submissions(TEST_USER_2_PAGES_FAVS, "favorites", {prev: overlap_fav_id})
        expect(favs1).to be_instance_of Array
        expect(favs1.length).to be 72
        favs_overlap.each do |fav|
          expect(fav[:fav_id]).to be > overlap_fav_id
        end
      end
    end
  end

  context 'when viewing a submission' do
    it 'displays basic data correctly' do
      sub_id = "16437648"
      sub = @fa.submission(sub_id)
      expect(sub[:title]).not_to be_blank
      expect(sub[:description]).not_to be_blank
      expect(sub[:description_body]).to eql(sub[:description])
      check_profile_link(sub)
      check_avatar(sub[:avatar], sub[:profile_name])
      check_submission_link(sub[:link], sub_id)
      check_date(sub[:posted], sub[:posted_at])
      expect(sub[:download]).to match(/https:\/\/d.facdn.net\/art\/[^\/]+\/[0-9]+\/[0-9]+\..+\.png/)
      # For an image submission, full == download
      expect(sub[:full]).to eql(sub[:download])
      check_thumbnail_link(sub[:thumbnail], sub_id)
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
      check_profile_link(sub)
      check_avatar(sub[:avatar], sub[:profile_name])
      check_submission_link(sub[:link], sub_id)
      check_date(sub[:posted], sub[:posted_at])
      expect(sub[:download]).to match(/https:\/\/d.facdn.net\/art\/[^\/]+\/stories\/[0-9]+\/[0-9]+\..+\.(rtf|doc|txt|docx|pdf)/)
      # For a story submission, full != download
      expect(sub[:full]).not_to be_blank
      expect(sub[:full]).not_to eql(sub[:download])
      check_thumbnail_link(sub[:thumbnail], sub_id)
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
      check_profile_link(sub)
      check_avatar(sub[:avatar], sub[:profile_name])
      check_submission_link(sub[:link], sub_id)
      check_date(sub[:posted], sub[:posted_at])
      expect(sub[:download]).to match(/https:\/\/d.facdn.net\/art\/[^\/]+\/music\/[0-9]+\/[0-9]+\..+\.(mp3|mid|wav|mpeg)/)
      # For a music submission, full != download
      expect(sub[:full]).not_to be_blank
      expect(sub[:full]).not_to eql(sub[:download])
      check_thumbnail_link(sub[:thumbnail], sub_id)
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
      check_profile_link(sub)
      check_avatar(sub[:avatar], sub[:profile_name])
      check_submission_link(sub[:link], sub_id)
      check_date(sub[:posted], sub[:posted_at])
      expect(sub[:download]).to match(/https:\/\/d.facdn.net\/art\/[^\/]+\/[0-9]+\/[0-9]+\..+\.swf/)
      # For a flash submission, full is nil
      expect(sub[:full]).to be_nil
      check_thumbnail_link(sub[:thumbnail], sub_id)
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
      check_profile_link(sub)
      check_avatar(sub[:avatar], sub[:profile_name])
      check_submission_link(sub[:link], sub_id)
      check_date(sub[:posted], sub[:posted_at])
      expect(sub[:download]).to match(/https:\/\/d.facdn.net\/art\/[^\/]+\/poetry\/[0-9]+\/[0-9]+\..+\.(rtf|doc|txt|docx|pdf)/)
      # For a potery submission, full is nil
      expect(sub[:full]).not_to be_nil
      check_thumbnail_link(sub[:thumbnail], sub_id)
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
      check_profile_link(sub)
      check_avatar(sub[:avatar], sub[:profile_name])
      check_submission_link(sub[:link], sub_id)
      check_date(sub[:posted], sub[:posted_at])
      expect(sub[:download]).to match(/https:\/\/d.facdn.net\/art\/[^\/]+\/[0-9]+\/[0-9]+\..+\.png/)
      # For an image submission, full == download
      expect(sub[:full]).to eql(sub[:download])
      check_thumbnail_link(sub[:thumbnail], sub_id)
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
  end

  context 'when viewing a journal post' do
    it 'displays basic data correctly' do
      journal_id = "6894930"
      journal = @fa.journal(journal_id)
      expect(journal[:title]).to eql("From Curl")
      expect(journal[:description]).to start_with("<div class=\"journal-body\">")
      expect(journal[:description]).to include("Curl Test")
      expect(journal[:description]).to end_with("</div>")
      expect(journal[:journal_header]).to be_nil
      expect(journal[:journal_body]).to eql("Curl Test")
      expect(journal[:journal_footer]).to be_nil
      check_profile_link(journal)
      check_avatar(journal[:avatar], journal[:profile_name])
      expect(journal[:link]).to match(/https:\/\/www.furaffinity.net\/journal\/#{journal_id}\/?/)
      check_date(journal[:posted], journal[:posted_at])
    end

    it 'fails when given non-existent journal' do
      expect { @fa.journal("6894929") }.to raise_error(FASystemError)
    end

    it 'parses journal header, body and footer' do
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
      check_profile_link(journal)
      check_avatar(journal[:avatar], journal[:profile_name])
      expect(journal[:link]).to match(/https:\/\/www.furaffinity.net\/journal\/#{journal_id}\/?/)
      check_date(journal[:posted], journal[:posted_at])
    end

    it 'handles non existent journal header' do
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
      check_profile_link(journal)
      check_avatar(journal[:avatar], journal[:profile_name])
      expect(journal[:link]).to match(/https:\/\/www.furaffinity.net\/journal\/#{journal_id}\/?/)
      check_date(journal[:posted], journal[:posted_at])
    end
  end

  context 'when listing comments' do
    context 'on a submission' do
      it 'displays a valid list of top level comments' do
        sub_id = "16437648"
        comments = @fa.submission_comments(sub_id, false)
        expect(comments).to be_instance_of Array
        expect(comments).not_to be_empty
        comments.each do |comment|
          expect(comment[:id]).to match(/[0-9]+/)
          check_profile_link(comment)
          check_avatar(comment[:avatar], comment[:profile_name])
          check_date(comment[:posted], comment[:posted_at])
          expect(comment[:text]).not_to be_blank
          expect(comment[:reply_to]).to be_blank
          expect(comment[:reply_level]).to be 0
        end
      end

      it 'handles empty comments section' do
        sub_id = "16437675"
        comments = @fa.submission_comments(sub_id, false)
        expect(comments).to be_instance_of Array
        expect(comments).to be_empty
      end

      it 'hides deleted comments by default' do
        submission_id = "16437663"
        comments = @fa.submission_comments(submission_id, false)
        expect(comments).to be_instance_of Array
        expect(comments.length).to be 1
        expect(comments[0][:text]).to eql("Non-deleted comment")
      end

      it 'handles comments deleted by author when specified' do
        submission_id = "16437663"
        comments = @fa.submission_comments(submission_id, true)
        expect(comments).to be_instance_of Array
        expect(comments.length).to be 2
        expect(comments[0]).to have_key(:id)
        expect(comments[0][:text]).to eql("Non-deleted comment")
        expect(comments[1]).not_to have_key(:id)
        expect(comments[1][:text]).to eql("Comment hidden by its owner")
      end

      it 'handles comments deleted by submission owner when specified' do
        submission_id = "32006442"
        comments_not_deleted = @fa.submission_comments(submission_id, false)
        expect(comments_not_deleted).to be_instance_of Array
        expect(comments_not_deleted).to be_empty
        # Ensure comments appear when viewing deleted
        comments = @fa.submission_comments(submission_id, true)
        expect(comments).to be_instance_of Array
        expect(comments.length).to be 1
        expect(comments[0]).not_to have_key(:id)
        expect(comments[0][:text]).to eql("Comment hidden by  the page owner")
      end

      it 'fails when given non-existent submission' do
        expect { @fa.submission_comments("16437650", false) }.to raise_error FASystemError
      end
      
      it 'correctly parses replies and reply levels' do
        comments = @fa.submission_comments("32006460", false)
        # Check first comment
        expect(comments[0][:id]).not_to be_blank
        expect(comments[0][:profile_name]).to eql("fafeed-3")
        check_profile_link(comments[0])
        check_avatar(comments[0][:avatar], comments[0][:profile_name])
        check_date(comments[0][:posted], comments[0][:posted_at])
        expect(comments[0][:text]).to eql("Base comment")
        expect(comments[0][:reply_to]).to be_blank
        expect(comments[0][:reply_level]).to be 0
        # Check second comment
        expect(comments[1][:id]).not_to be_blank
        expect(comments[1][:profile_name]).to eql("fafeed-3")
        check_profile_link(comments[1])
        check_avatar(comments[1][:avatar], comments[1][:profile_name])
        check_date(comments[1][:posted], comments[1][:posted_at])
        expect(comments[1][:text]).to eql("First reply")
        expect(comments[1][:reply_to]).not_to be_blank
        expect(comments[1][:reply_to]).to eql(comments[0][:id])
        expect(comments[1][:reply_level]).to be 1
        # Check third comment
        expect(comments[2][:id]).not_to be_blank
        expect(comments[2][:profile_name]).to eql("fafeed-no-watchers")
        check_profile_link(comments[2])
        check_avatar(comments[2][:avatar], comments[2][:profile_name])
        check_date(comments[2][:posted], comments[2][:posted_at])
        expect(comments[2][:text]).to eql("Another reply")
        expect(comments[2][:reply_to]).not_to be_blank
        expect(comments[2][:reply_to]).to eql(comments[1][:id])
        expect(comments[2][:reply_level]).to be 2
      end

      it 'handles replies to deleted comments' do
        comments = @fa.submission_comments("32052941", true)
        expect(comments).to be_instance_of Array
        expect(comments.length).to be 2
        # Check hidden comment
        expect(comments[0]).not_to have_key(:id)
        expect(comments[0][:text]).to start_with("Comment hidden by")
        expect(comments[0][:reply_to]).to eql("")
        expect(comments[0][:reply_level]).to be 0
        # Check reply comment
        expect(comments[1][:id]).not_to be_blank
        expect(comments[1][:text]).not_to start_with("Comment hidden by")
        expect(comments[1]).to have_key(:profile_name)
        expect(comments[1][:reply_level]).to be 1
        expect(comments[1][:reply_to]).to eql("hidden")
      end

      it 'handles replies to hidden deleted comments' do
        comments = @fa.submission_comments("32052941", false)
        expect(comments).to be_instance_of Array
        expect(comments.length).to be 1
        # Reply comment should be only comment
        expect(comments[0][:id]).not_to be_blank
        expect(comments[0][:text]).not_to start_with("Comment hidden by")
        expect(comments[0]).to have_key(:profile_name)
        expect(comments[0][:reply_level]).to be 1
        expect(comments[0][:reply_to]).to eql("hidden")
      end

      it 'handles 2 replies to the same comment' do
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

      it 'handles deleted replies to deleted comments' do
        comments = @fa.submission_comments("32057697", true)
        expect(comments).to be_instance_of Array
        expect(comments.length).to be 2
        # Check hidden comment
        expect(comments[0]).not_to have_key(:id)
        expect(comments[0][:text]).to start_with("Comment hidden by")
        expect(comments[0][:reply_level]).to be 0
        expect(comments[0][:reply_to]).to eql("")
        # Check reply comment
        expect(comments[1]).not_to have_key(:id)
        expect(comments[1][:text]).to start_with("Comment hidden by")
        expect(comments[1][:reply_level]).to be 1
        expect(comments[1][:reply_to]).to eql("hidden")
      end

      it 'handles comments to max depth' do
        comments = @fa.submission_comments("32057717", false)
        expect(comments).to be_instance_of Array
        expect(comments.length).to be 22
        last_comment_id = ""
        level = 0
        comments.each do |comment|
          expect(comment[:id]).to match(/[0-9]+/)
          check_profile_link(comment)
          check_avatar(comment[:avatar], comment[:profile_name])
          check_date(comment[:posted], comment[:posted_at])
          expect(comment[:text]).not_to be_blank
          expect(comment[:reply_to]).to eql(last_comment_id)
          expect(comment[:reply_level]).to be level

          if level <= 19
            last_comment_id = comment[:id]
            level += 1
          end
        end
      end

      it 'handles edited comments' do
        comments = @fa.submission_comments("32057705", false)
        expect(comments).to be_instance_of Array
        expect(comments.length).to be 2
        # Check edited comment
        expect(comments[0][:id]).to match(/[0-9]+/)
        check_profile_link(comments[0])
        check_avatar(comments[0][:avatar], comments[0][:profile_name])
        check_date(comments[0][:posted], comments[0][:posted_at])
        expect(comments[0][:text]).not_to be_blank
        expect(comments[0][:reply_to]).to be_blank
        expect(comments[0][:reply_level]).to be 0
        # Check non-edited comment
        expect(comments[1][:id]).to match(/[0-9]+/)
        check_profile_link(comments[1])
        check_avatar(comments[1][:avatar], comments[1][:profile_name])
        check_date(comments[1][:posted], comments[1][:posted_at])
        expect(comments[1][:text]).not_to be_blank
        expect(comments[1][:reply_to]).to be_blank
        expect(comments[1][:reply_level]).to be 0
      end

      it 'handles reply chain, followed by reply to base comment' do
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

    context 'on a journal' do
      it 'displays a valid list of top level comments' do
        journal_id = "6704315"
        comments = @fa.journal_comments(journal_id, false)
        expect(comments).to be_instance_of Array
        expect(comments).not_to be_empty
        comments.each do |comment|
          expect(comment[:id]).to match(/[0-9]+/)
          check_profile_link(comment)
          check_avatar(comment[:avatar], comment[:profile_name])
          check_date(comment[:posted], comment[:posted_at])
          expect(comment[:text]).not_to be_blank
          expect(comment[:reply_to]).to be_blank
          expect(comment[:reply_level]).to be 0
        end
      end

      it 'handles empty comments section' do
        journal_id = "6704317"
        comments = @fa.journal_comments(journal_id, false)
        expect(comments).to be_instance_of Array
        expect(comments).to be_empty
      end

      it 'hides deleted comments by default' do
        journal_id = "6704520"
        comments = @fa.journal_comments(journal_id, false)
        expect(comments).to be_instance_of Array
        expect(comments.length).to be 1
        expect(comments[0][:text]).to eql("Non-deleted comment")
      end

      it 'handles comments deleted by author when specified' do
        journal_id = "6704520"
        comments = @fa.journal_comments(journal_id, true)
        expect(comments).to be_instance_of Array
        expect(comments.length).to be 2
        expect(comments[0]).to have_key(:id)
        expect(comments[0][:text]).to eql("Non-deleted comment")
        expect(comments[1]).not_to have_key(:id)
        expect(comments[1][:text]).to eql("Comment hidden by its owner")
      end

      it 'handles comments deleted by journal owner when specified' do
        journal_id = "9185920"
        comments_not_deleted = @fa.journal_comments(journal_id, false)
        expect(comments_not_deleted).to be_instance_of Array
        expect(comments_not_deleted).to be_empty
        # Ensure comments appear when viewing deleted
        comments = @fa.journal_comments(journal_id, true)
        expect(comments).to be_instance_of Array
        expect(comments.length).to be 1
        expect(comments[0]).not_to have_key(:id)
        expect(comments[0][:text]).to eql("Comment hidden by  the page owner")
      end

      it 'fails when given non-existent journal' do
        expect { @fa.journal_comments("6894929", false) }.to raise_error(FASystemError)
      end

      it 'correctly parses replies and reply levels' do
        comments = @fa.journal_comments("6894788", false)
        # Check first comment
        expect(comments[0][:id]).not_to be_blank
        expect(comments[0][:profile_name]).to eql("fafeed-3")
        check_profile_link(comments[0])
        check_avatar(comments[0][:avatar], comments[0][:profile_name])
        check_date(comments[0][:posted], comments[0][:posted_at])
        expect(comments[0][:text]).to eql("Base journal comment")
        expect(comments[0][:reply_to]).to be_blank
        expect(comments[0][:reply_level]).to be 0
        # Check second comments
        expect(comments[1][:id]).not_to be_blank
        expect(comments[1][:profile_name]).to eql("fafeed-3")
        check_profile_link(comments[1])
        check_avatar(comments[1][:avatar], comments[1][:profile_name])
        check_date(comments[1][:posted], comments[1][:posted_at])
        expect(comments[1][:text]).to eql("Reply to journal comment")
        expect(comments[1][:reply_to]).not_to be_blank
        expect(comments[1][:reply_to]).to eql(comments[0][:id])
        expect(comments[1][:reply_level]).to be 1
        # Check third comments
        expect(comments[2][:id]).not_to be_blank
        expect(comments[2][:profile_name]).to eql("fafeed-no-watchers")
        check_profile_link(comments[2])
        check_avatar(comments[2][:avatar], comments[2][:profile_name])
        check_date(comments[2][:posted], comments[2][:posted_at])
        expect(comments[2][:text]).to eql("Another reply on this journal")
        expect(comments[2][:reply_to]).not_to be_blank
        expect(comments[2][:reply_to]).to eql(comments[1][:id])
        expect(comments[2][:reply_level]).to be 2
      end

      it 'handles replies to deleted comments' do
        comments = @fa.journal_comments("9187935", true)
        expect(comments).to be_instance_of Array
        expect(comments.length).to be 2
        # Check hidden comment
        expect(comments[0]).not_to have_key(:id)
        expect(comments[0][:text]).to start_with("Comment hidden by")
        expect(comments[0][:reply_to]).to eql("")
        expect(comments[0][:reply_level]).to be 0
        # Check reply comment
        expect(comments[1][:id]).not_to be_blank
        expect(comments[1][:text]).not_to start_with("Comment hidden by")
        expect(comments[1]).to have_key(:profile_name)
        expect(comments[1][:reply_level]).to be 1
        expect(comments[1][:reply_to]).to eql("hidden")
      end

      it 'handles replies to hidden deleted comments' do
        comments = @fa.journal_comments("9187935", false)
        expect(comments).to be_instance_of Array
        expect(comments.length).to be 1
        # Reply comment should be only comment
        expect(comments[0][:id]).not_to be_blank
        expect(comments[0][:text]).not_to start_with("Comment hidden by")
        expect(comments[0]).to have_key(:profile_name)
        expect(comments[0][:reply_level]).to be 1
        expect(comments[0][:reply_to]).to eql("hidden")
      end

      it 'handles 2 replies to the same comment' do
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

      it 'handles deleted replies to deleted comments' do
        comments = @fa.journal_comments("9187934", true)
        expect(comments).to be_instance_of Array
        expect(comments.length).to be 2
        # Check hidden comment
        expect(comments[0]).not_to have_key(:id)
        expect(comments[0][:text]).to start_with("Comment hidden by")
        expect(comments[0][:reply_level]).to be 0
        expect(comments[0][:reply_to]).to eql("")
        # Check reply comment
        expect(comments[1]).not_to have_key(:id)
        expect(comments[1][:text]).to start_with("Comment hidden by")
        expect(comments[1][:reply_level]).to be 1
        expect(comments[1][:reply_to]).to eql("hidden")
      end

      it 'handles comments to max depth' do
        comments = @fa.submission_comments("32057717", false)
        expect(comments).to be_instance_of Array
        expect(comments.length).to be 22
        last_comment_id = ""
        level = 0
        comments.each do |comment|
          expect(comment[:id]).to match(/[0-9]+/)
          check_profile_link(comment)
          check_avatar(comment[:avatar], comment[:profile_name])
          check_date(comment[:posted], comment[:posted_at])
          expect(comment[:text]).not_to be_blank
          expect(comment[:reply_to]).to eql(last_comment_id)
          expect(comment[:reply_level]).to be level

          if level <= 19
            last_comment_id = comment[:id]
            level += 1
          end
        end
      end

      it 'handles edited comments' do
        comments = @fa.journal_comments("9187948", false)
        expect(comments).to be_instance_of Array
        expect(comments.length).to be 2
        # Check edited comment
        expect(comments[0][:id]).to match(/[0-9]+/)
        check_profile_link(comments[0])
        check_avatar(comments[0][:avatar], comments[0][:profile_name])
        check_date(comments[0][:posted], comments[0][:posted_at])
        expect(comments[0][:text]).not_to be_blank
        expect(comments[0][:reply_to]).to be_blank
        expect(comments[0][:reply_level]).to be 0
        # Check non-edited comment
        expect(comments[1][:id]).to match(/[0-9]+/)
        check_profile_link(comments[1])
        check_avatar(comments[1][:avatar], comments[1][:profile_name])
        check_date(comments[1][:posted], comments[1][:posted_at])
        expect(comments[1][:text]).not_to be_blank
        expect(comments[1][:reply_to]).to be_blank
        expect(comments[1][:reply_level]).to be 0
      end

      it 'handles reply chain, followed by reply to base comment' do
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

  context 'when searching submissions' do
    it 'returns a list of submission data' do
      results = @fa.search({"q" => "YCH"})
      expect(results).to be_instance_of Array
      expect(results).not_to be_empty
      results.each(&method(:check_submission))
    end

    it 'handles blank search cleanly' do
      results = @fa.search({q: ""})
      expect(results).to be_instance_of Array
      expect(results).to be_empty
    end

    it 'handles search queries with a space in them' do
      results = @fa.search({"q" => "YCH deer"})
      expect(results).to be_instance_of Array
      expect(results).not_to be_empty
      results.each(&method(:check_submission))
    end

    it 'displays a different page 1 to page 2' do
      # Get page 1
      results1 = @fa.search({"q" => "YCH"})
      expect(results1).to be_instance_of Array
      expect(results1).not_to be_empty
      # Get page 2
      results2 = @fa.search({"q" => "YCH", "page" => "2"})
      expect(results2).to be_instance_of Array
      expect(results2).not_to be_empty
      # Check they're different enough
      check_results_lists_are_different(results1, results2)
    end

    it 'works when making the same search twice' do
      # There was an awkward caching issue breaking this, hence this test.
      results1 = @fa.search({"q" => "YCH"})
      expect(results1).to be_instance_of Array
      expect(results1).not_to be_empty
      expect(results1.length).to be > 20
      # Get page 2
      results2 = @fa.search({"q" => "YCH"})
      expect(results2).to be_instance_of Array
      expect(results2).not_to be_empty
      expect(results2.length).to be > 20
    end

    it 'returns a specific set of test submissions when using a rare test keyword' do
      results = @fa.search({"q" => "rare_test_keyword"})
      expect(results).to be_instance_of Array
      expect(results).not_to be_empty
      expect(results.length).to be 3
      result_id_list = results.map{|result| result[:id]}
      expect(result_id_list).to include("32052941")
      expect(result_id_list).to include("32057670")
      expect(result_id_list).to include("32057697")
    end

    it 'displays a number of results equal to the perpage setting' do
      results_long = @fa.search({"q" => "YCH", "perpage" => "72"})
      expect(results_long).to be_instance_of Array
      expect(results_long).not_to be_empty
      expect(results_long.length).to be >= 70

      results_med = @fa.search({"q" => "YCH", "perpage" => "48"})
      expect(results_med).to be_instance_of Array
      expect(results_med).not_to be_empty
      expect(results_med.length).to be >= 46
      expect(results_med.length).to be < 49

      results_short = @fa.search({"q" => "YCH", "perpage" => "24"})
      expect(results_short).to be_instance_of Array
      expect(results_short).not_to be_empty
      expect(results_short.length).to be >= 22
      expect(results_short.length).to be < 25
    end

    it 'defaults to ordering by date desc' do
      results = @fa.search({"q" => "YCH", "perpage" => "72"})
      expect(results).to be_instance_of Array
      expect(results).not_to be_empty
      results_date = @fa.search({"q" => "YCH", "perpage" => "72", "order_by" => "date"})
      expect(results).to be_instance_of Array
      expect(results).not_to be_empty

      # Check they're similar enough
      check_results_lists_are_similar(results, results_date)

      # Check it's roughly date ordered. FA results are not exactly date ordered.
      first_submission = @fa.submission(results[0][:id])
      first_datetime = Time.parse(first_submission[:posted] + ' UTC')
      last_submission = @fa.submission(results[-1][:id])
      last_datetime = Time.parse(last_submission[:posted] + ' UTC')
      expect(last_datetime).to be < first_datetime
    end

    it 'can search by relevancy and popularity, which give a different order to date' do
      results_date = @fa.search({"q" => "YCH", "perpage" => "24", "order_by" => "date"})
      results_rele = @fa.search({"q" => "YCH", "perpage" => "24", "order_by" => "relevancy"})
      results_popu = @fa.search({"q" => "YCH", "perpage" => "24", "order_by" => "popularity"})
      check_results_lists_are_different(results_date, results_rele)
      check_results_lists_are_different(results_rele, results_popu)
      check_results_lists_are_different(results_popu, results_date)
    end

    it 'can specify order direction as ascending' do
      results_asc = @fa.search({"q" => "YCH", "perpage" => "24", "order_direction" => "asc"})
      results_desc = @fa.search({"q" => "YCH", "perpage" => "24", "order_direction" => "desc"})
      check_results_lists_are_different(results_asc, results_desc)
    end

    it 'can specify shorter range, which delivers fewer results' do
      big_results = @fa.search({"q" => "garden", "perpage" => 72})
      expect(big_results).to be_instance_of Array
      expect(big_results).not_to be_empty
      small_results = @fa.search({"q" => "garden", "perpage" => 72, "range" => "day"})
      expect(small_results).to be_instance_of Array
      expect(small_results).not_to be_empty

      expect(big_results.length).to be > small_results.length
    end

    it 'can specify search mode for the terms in the query' do
      extended_or_results = @fa.search({"q" => "deer | lion", "perpage" => 72})
      extended_and_results = @fa.search({"q" => "deer & lion", "perpage" => 72})
      or_results = @fa.search({"q" => "deer lion", "perpage" => 72, "mode" => "any"})
      and_results = @fa.search({"q" => "deer lion", "perpage" => 72, "mode" => "all"})

      check_results_lists_are_different(extended_and_results, extended_or_results)
      check_results_lists_are_different(and_results, or_results)

      check_results_lists_are_similar(extended_or_results, or_results)
      check_results_lists_are_similar(extended_and_results, and_results)
    end

    it 'can specify ratings to display, and honours that selection' do
      only_adult = @fa.search({"q" => "ych", "perpage" => 24, "rating" => "adult"})
      only_sfw_or_mature = @fa.search({"q" => "ych", "perpage" => 24, "rating" => "mature,general"})

      check_results_lists_are_different(only_adult, only_sfw_or_mature)

      only_adult.each do |submission|
        full_submission = @fa.submission(submission[:id])
        expect(full_submission[:rating]).to eql("Adult")
      end

      general_count = 0
      mature_count = 0
      only_sfw_or_mature.each do |submission|
        full_submission = @fa.submission(submission[:id])
        expect(full_submission[:rating]).not_to eql("Adult")
        if full_submission[:rating] == "General"
          general_count += 1
        else
          mature_count += 1
        end
      end
      expect(general_count).to be > 0
      expect(mature_count).to be > 0
    end

    it 'displays only sfw results when only adult is selected, and sfw mode is on' do
      @fa.safe_for_work = true
      results = @fa.search({"q" => "ych", "perpage" => 24, "rating" => "adult"})
      results.each do |submission|
        begin
          full_submission = @fa.submission(submission[:id])
          expect(full_submission[:rating]).to eql("General")
        rescue FASystemError
        end
      end
    end

    it 'can specify a content type for results, only returns that content type' do
      results_poem = @fa.search({"q" => "deer", "perpage" => 72, "type" => "poetry"})
      results_photo = @fa.search({"q" => "deer", "perpage" => 72, "type" => "photo"})
      check_results_lists_are_different(results_photo, results_poem)
    end

    it 'can specify multiple content types for results, and only displays those types' do
      results_image = @fa.search({"q" => "deer", "perpage" => 72, "type" => "photo,art"})
      results_swf_music = @fa.search({"q" => "deer", "perpage" => 72, "type" => "flash,music"})
      check_results_lists_are_different(results_image, results_swf_music)
    end

    it 'ignores other unused parameters' do
      results = @fa.search({"q" => "ych", "foo" => "bar"})
      expect(results).to be_instance_of Array
      expect(results).not_to be_empty
    end

    it 'raises an error if given invalid option for a parameter' do
      expect { @fa.search({"q" => "ych", "perpage" => 100}) }.to raise_error(FASearchError)
    end

    it 'raises an error if given an invalid option for a multi-value parameter' do
      expect { @fa.search({"q" => "ych", "rating" => "adult,lewd"}) }.to raise_error(FASearchError)
    end
  end

  context 'when reading new submission notifications' do
    it 'will correctly parse current user' do
      @fa.login_cookie = COOKIE_TEST_USER_2
      new_subs = @fa.new_submissions(nil)
      expect(new_subs[:current_user][:name]).to eql(TEST_USER_2)
      check_profile_link(new_subs[:current_user])
    end

    it 'should handle zero notifications' do
      @fa.login_cookie = COOKIE_TEST_USER_2
      new_subs = @fa.new_submissions(nil)
      expect(new_subs[:new_submissions]).to be_instance_of Array
      expect(new_subs[:new_submissions]).to be_empty
    end

    it 'should handle deleted notifications'
    it 'should hide nsfw submissions if sfw=1 is specified'
    it 'returns a valid list of new submission notifications'
    it 'handles paging correctly' do
      @fa.login_cookie = COOKIE_TEST_USER_3
      all_subs = @fa.new_submission(nil)
      expect(all_subs).to be_instance_of Array
      expect(all_subs).not_to be_empty

      second_sub = all_subs[1]
      all_from_second = @fa.new_submissions(second_sub[:id])
      expect(all_from_second).to be_instance_of Array
      expect(all_from_second).not_to be_empty

      all_after_second = @fa.new_submission(second_sub[:id]-1)
      expect(all_after_second).to be_instance_of Array
      expect(all_after_second).not_to be_empty

      expect(all_from_second.length).to be(all_subs.length - 1)
      expect(all_from_second[0][:id]).to eql(all_subs[1][:id])
      expect(all_after_second.length).to be(all_subs.length - 2)
      expect(all_after_second[0][:id]).to eql(all_subs[2][:id])
    end
  end

  context 'when reading notifications' do
    it 'will correctly parse current user' do
      @fa.login_cookie = COOKIE_TEST_USER_2
      notifications = @fa.notifications(false)
      expect(notifications[:current_user][:name]).to eql(TEST_USER_2)
      check_profile_link(notifications[:current_user])
    end

    it 'should not return anything unless login cookie is given'
    it 'should contain all 6 types of notifications' do
      @fa.login_cookie = COOKIE_TEST_USER_2
      notifications = @fa.notifications(false)
      expect(notifications).to have_key(:new_watches)
      expect(notifications).to have_key(:new_submission_comments)
      expect(notifications).to have_key(:new_journal_comments)
      expect(notifications).to have_key(:new_shouts)
      expect(notifications).to have_key(:new_favorites)
      expect(notifications).to have_key(:new_journals)
    end

    context 'watcher notifications' do
      it 'should handle zero new watchers'
      it 'returns a list of new watcher notifications'
      it 'should hide deleted watcher notifications by default'
      it 'should display deleted watcher notifications when specified'
    end

    context 'submission comment notifications' do
      it 'should handle zero submission comment notifications'
      it 'returns a list of new submission comment notifications'
      it 'correctly parses base level comments to your submissions'
      it 'correctly parses replies to your comments on your submissions'
      it 'correctly parses replies to your comments on their submissions'
      it 'correctly parses replies to your comments on someone else\'s submissions'
      it 'hides deleted comments by default'
      it 'displays deleted comment notifications when specified'
      it 'hides comments on deleted submissions by default'
      it 'displays comments on deleted submissions when specified'
    end

    context 'journal comment notifications' do
      it 'should handle zero journal comment notifications'
      it 'returns a list of new journal comment notifications'
      it 'correctly parses base level comments to your journals'
      it 'correctly parses replies to your comments on your journals'
      it 'correctly parses replies to your comments on their journals'
      it 'correctly parses replies to your comments on someone else\'s journals'
      it 'hides deleted comments by default'
      it 'displays deleted comment notifications when specified'
      it 'hides comments on deleted journals by default'
      it 'displays comments on deleted journals when specified'
    end

    context 'shout notifications' do
      it 'should handle zero shout notifications'
      it 'returns a list of new shout notifications'
      it 'hides deleted shouts by default'
      it 'displays deleted shout notifications when specified'
    end

    context 'favourite notifications' do
      it 'should handle zero favourite notifications'
      it 'returns a list of new favourite notifications'
      it 'hides deleted favourites by default'
      it 'displays deleted favourite notifications when specified'
    end

    context 'journal notifications' do
      it 'should handle zero new journals'
      it 'returns a list of new journal notifications'
    end
  end

  context 'when posting a new journal' do
    it 'requires a login cookie'
    it 'fails if not given title'
    it 'fails if not given description'
    it 'can post a new journal entry using json'
    it 'can post a new journal entry using query params'
  end

  private

  # noinspection RubyResolve
  def check_submission(submission, blank_profile=false, blank_title=false)
    # Check ID
    expect(submission[:id]).to match(/^[0-9]+$/)
    # Check title
    if blank_title
      expect(submission[:title]).to be_blank
    else
      expect(submission[:title]).not_to be_blank
    end
    # Check thumbnail
    check_thumbnail_link(submission[:thumbnail], submission[:id])
    # Check link
    check_submission_link(submission[:link], submission[:id])
    # Check profile
    if blank_profile
      expect(submission[:name]).to be_blank
      expect(submission[:profile]).to be_blank
      expect(submission[:profile_name]).to be_blank
    else
      check_profile_link submission
    end
  end

  def check_profile_link(item, watch_list=false)
    expect(item[:name]).not_to be_blank
    expect(item[watch_list ? :link : :profile]).to eql "https://www.furaffinity.net/user/#{item[:profile_name]}/"
    expect(item[:profile_name]).to match(FAExport::Application::USER_REGEX)
  end

  def check_date(date_string, iso_string)
    expect(date_string).not_to be_blank
    expect(date_string).to match(/[A-Z][a-z]{2} [0-9]+[a-z]{2}, [0-9]{4} [0-9]{2}:[0-9]{2}/)
    expect(iso_string).not_to be_blank
    expect(iso_string).to eql(Time.parse(date_string + ' UTC').iso8601)
  end

  def check_avatar(avatar_link, username)
    expect(avatar_link).to match(/^https:\/\/a.facdn.net\/[0-9]+\/#{username}.gif$/)
  end

  def check_submission_link(link, id)
    expect(link).to match(/^https:\/\/www.furaffinity.net\/view\/#{id}\/?$/)
  end

  def check_thumbnail_link(link, id)
    expect(link).to match(/^https:\/\/t.facdn.net\/#{id}@[0-9]{2,3}-[0-9]+.jpg$/)
  end

  def check_results_lists_are_similar(results1, result2)
    results1_ids = results1.map{|result| result[:id]}
    results2_ids = result2.map{|result| result[:id]}
    intersection = results1_ids & results2_ids

    threshold = [results1_ids.length, results2_ids.length].max * 0.9
    expect(intersection.length).to be >= threshold
  end

  def check_results_lists_are_different(results1, results2)
    results1_ids = results1.map{|result| result[:id]}
    results2_ids = results2.map{|result| result[:id]}
    intersection = results1_ids & results2_ids

    threshold = [results1_ids.length, results2_ids.length].max * 0.1
    expect(intersection.length).to be <= threshold
  end
end