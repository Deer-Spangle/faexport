
require './lib/faexport'

require 'rspec'

describe 'FA parser' do
  TEST_USER = "fafeed"
  TEST_USER_2 = "fafeed-2"
  # Specific test user cases
  TEST_USER_NOT_EXIST = "fafeed-does-not-exist"
  TEST_USER_OVER_200_WATCHERS = "fender"
  TEST_USER_NO_WATCHERS = "fafeed-no-watchers"
  TEST_USER_NO_JOURNALS = TEST_USER_NO_WATCHERS
  TEST_USER_OVER_25_JOURNALS = TEST_USER_OVER_200_WATCHERS
  TEST_USER_EMPTY_GALLERIES = TEST_USER_NO_WATCHERS
  TEST_USER_2_PAGES_GALLERY_AND_SCRAPS = "rajii"
  TEST_USER_HIDDEN_FAVS = TEST_USER_NO_WATCHERS
  TEST_USER_HIDDEN_FAVS_COOKIE = ENV['test_cookie_hidden_favs']

  before do
    config = File.exist?('settings-test.yml') ? YAML.load_file('settings-test.yml') : {}
    @app = FAExport::Application.new(config).instance_variable_get(:@instance)
    @fa = @app.instance_variable_get(:@fa)
    @fa.login_cookie = ENV['test_cookie']
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
      expect(profile[:avatar]).to match(/^https:\/\/a.facdn.net\/[0-9]+\/#{TEST_USER}.gif$/)
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
      profile_with_underscores = "l[i]s"
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
        expect(shout[:avatar]).to match(/^https:\/\/a.facdn.net\/[0-9]+\/#{shout[:profile_name]}.gif$/)
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
          gallery1 = @fa.submissions(TEST_USER_2_PAGES_GALLERY_AND_SCRAPS, folder, {})
          gallery2 = @fa.submissions(TEST_USER_2_PAGES_GALLERY_AND_SCRAPS, folder, {page: 2})
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
        @fa.login_cookie = TEST_USER_HIDDEN_FAVS_COOKIE
        favs = @fa.submissions(TEST_USER_HIDDEN_FAVS, "favorites", {})
        expect(favs).to be_instance_of Array
        expect(favs).not_to be_empty
      end

      it 'uses next parameter to display submissions after a specified fav id'
      it 'uses prev parameter to display only submissions before a specified fav id'
    end
  end

  context 'when viewing a submission' do
    it 'displays basic data correctly'
    it 'fails when given non-existent submissions'
    it 'parses keywords'
    it 'has identical description and description_body'
    it 'displays stories correctly'
    it 'displays music correctly'
    it 'handles flash files correctly'
    it 'still displays correctly when logged in as submission owner'
    it 'hides nsfw submission if sfw is set'
  end

  context 'when viewing a journal post' do
    it 'displays basic data correctly'
    it 'fails when given non-existent journal'
    it 'parses journal header, body and footer'
    it 'handles non existent journal header'
    it 'handles non existent journal footer'
  end

  context 'when listing comments on a submission' do
    it 'displays a valid list of comments'
    it 'handles empty comments section'
    it 'hides deleted comments by default'
    it 'handles comments deleted by author when specified'
    it 'handles comments deleted by submission owner when specified'
    it 'fails when given non-existent submission'
    it 'correctly parses base level comments which are not replies'
    it 'correctly parses replies and reply levels'
    it 'handles replies to deleted comments'
    it 'handles 2 replies to the same comment'
    it 'handles deleted replies to deleted comments'
  end

  context 'when searching submissions' do
    it 'returns a list of submission IDs'
    it 'returns a list of submission data when full=1'
    it 'handles search queries with a space in them'
    it 'displays a different page 1 to page 2'
    it 'returns a specific set of test submissions when using a rare test keyword'
    it 'displays a number of results equal to the perpage setting'
    it 'defaults to ordering by date desc'
    it 'can search by relevancy and popularity, which give a different order to date'
    it 'can specify order direction as ascending'
    it 'can specify shorter range, which delivers fewer results'
    it 'can specify search mode for the terms in the query'
    it 'can specify ratings to display, and honours that selection'
    it 'displays nothing when only adult is selected, and sfw mode is on'
    it 'can specify a content type for results, only returns that content type'
    it 'can specify multiple content types for results, and only displays those types'
  end

  context 'when reading new submission notifications' do
    it 'will correctly parse current user'
    it 'should not return anything unless login cookie is given'
    it 'should handle zero notifications'
    it 'should handle deleted notifications'
    it 'should hide nsfw submissions if sfw=1 is specified'
    it 'returns a valid list of new submission notifications'
  end

  context 'when reading notifications' do
    it 'will correctly parse current user'
    it 'should not return anything unless login cookie is given'
    it 'should contain all 6 types of notifications'

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
    expect(submission[:thumbnail]).to match(/^https:\/\/t.facdn.net\/#{submission[:id]}@[0-9]{2,3}-[0-9]+.jpg$/)
    # Check link
    expect(submission[:link]).to match(/^https:\/\/www.furaffinity.net\/view\/#{submission[:id]}\/?$/)
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
end