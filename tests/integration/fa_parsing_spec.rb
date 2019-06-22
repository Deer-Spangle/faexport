
require './lib/faexport'

require 'rspec'

describe 'FA parser' do
  TEST_USER = "fafeed"

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
        submissions.map do |submission|
          # Check ID
          expect(submission[:id]).to match(/[0-9]+/)
          # Check title
          expect(submission[:title]).not_to be("")
          # Check thumbnail
          expect(submission[:thumbnail]).to match(/https:\/\/t.facdn.net\/#{submission[:id]}@[0-9]{2,3}-[0-9]+.jpg/)
          # Check link
          expect(submission[:link]).to eql "https://www.furaffinity.net/view/#{submission[:id]}/"
          # Check name
          expect(submission[:name]).not_to be("")
          # Check profile link
          expect(submission[:profile]).to eql "https://www.furaffinity.net/user/#{submission[:profile_name]}/"
          # Check profile name
          expect(submission[:profile_name]).to match(FAExport::Application::USER_REGEX)
        end
      end
    end

    it 'only returns SFW results, if specified' do
      @fa.safe_for_work = true
      home = @fa.home
      home.map do |_, submissions|
        expect(submissions).not_to be_empty
        submissions.map do |submission|
          full_submission = @fa.submission(p submission[:id])
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
      expect(profile[:avatar]).to match(/https:\/\/a.facdn.net\/[0-9]+\/#{TEST_USER}.gif/)
      expect(profile[:full_name]).not_to be_blank
      expect(profile[:artist_type]).not_to be_blank
      expect(profile[:user_title]).not_to be_blank
      expect(profile[:user_title]).to eql(profile[:artist_type])
      expect(profile[:current_mood]).to eql("accomplished")
      # Check registration date
      expect(profile[:registered_since]).not_to be_blank
      expect(profile[:registered_since]).to match(/[A-Z][a-z]{2} [0-9]+[a-z]{2}, [0-9]{4} [0-9]{2}:[0-9]{2}/)
      expect(profile[:registered_at]).not_to be_blank
      expect(profile[:registered_at]).to eql(Time.parse(profile[:registered_since] + ' UTC').iso8601)
      # Check description
      expect(profile[:artist_profile]).not_to be_blank
      # Check numeric values
      [:pageviews, :submissions, :comments_received, :comments_given, :journals, :favorites].each do |key|
        expect(profile[key]).not_to be_blank
        expect(profile[key]).to match(/[0-9]+/)
      end
    end

    it 'fails when given a non-existent profile' do
      expect { @fa.user("fafeed-does-not-exist") }.to raise_error(FASystemError)
    end

    it 'handles square brackets in profile name' do
      profile_with_underscores = "l[i]s"
      profile = @fa.user(profile_with_underscores)
      expect(profile[:name].downcase).to eql(profile_with_underscores)
    end

    it 'shows featured submission'
    it 'handles featured submission not being set'
    it 'shows profile id'
    it 'handles profile id not being set'
    it 'shows artist information'
    it 'handles blank artist information box'
    it 'shows contact information'
    it 'handles no contact information being set'
    it 'lists watchers of specified account'
    it 'lists accounts watched by specified account'
  end

  context 'when listing user\'s watchers/watchees' do
    it 'displays a valid list of profile names'
    it 'fails when given a non-existent profile'
    it 'displays a different list for is watching vs watched by'
    it 'returns 200 users when more than one page exists'
    it 'displays a second page, different than the first'
    it 'handles an empty watchers list'
  end

  context 'when listing a user\'s shouts' do
    it 'displays a valid list of shouts'
    it 'fails when given a non-existent user'
    it 'handles an empty shouts list'
  end

  context 'when displaying commission information pages' do
    it 'handles empty commission information'
    it 'displays valid commission information data'
    it 'fails when given a non-existent user'
  end

  context 'when listing a user\'s journals' do
    it 'returns a list of journal IDs'
    it 'fails when given a non-existent user'
    it 'handles an empty journal listing'
    it 'displays a second page, different than the first'
    it 'displays valid full data'
    it 'pages full data correctly'
  end

  context 'when viewing user galleries' do
    it 'returns a list of valid submission ids'
    it 'fails when given a non-existent user'
    it 'handles an empty gallery'
    it 'displays full data correctly for the gallery'
    it 'returns a list of valid submission ids in scraps'
    it 'handles paging correctly'
    it 'doesn\'t include deleted submissions by default'
    it 'includes deleted submissions when specified'
    it 'hides nsfw submissions if sfw is set'
  end

  context 'when viewing user favourites' do
    it 'returns a list of valid favourite ids'
    it 'fails when given a non-existent user'
    it 'handles an empty (or hidden) favourites list'
    it 'displays full data correctly for favourites'
    it 'uses next parameter to display submissions after a specified fav id'
    it 'uses prev parameter to display only submissions before a specified fav id'
    it 'doesn\'t include deleted submissions by default'
    it 'includes deleted submissions when specified'
    it 'hides nsfw submissions if sfw is set'
    it 'displays favourites of currently logged in user even if hidden'
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
end