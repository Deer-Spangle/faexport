require 'rspec'

describe 'Home endpoint' do
  before do
    config = File.exist?('settings-test.yml') ? YAML.load_file('settings-test.yml') : {}
    @app = FAExport::Application, config
    @fa = @app.instance_variable_get(:@fa)
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
          expect(submission[:thumbnail]).to start_with "https://"
          expect(submission[:thumbnail]).to end_with ".jpg"
          expect(submission[:thumbnail]).to include("t.facdn.net")
          expect(submission[:thumbnail]).to match(/https:\/\/t.facdn.net\/#{submission[:id]}@[1-9]00-[0-9]+.jpg/)
          # Check link
          expect(submission[:link]).to equal "https://www.furaffinity.net/view/#{submission[:id]}/"
          # Check name
          expect(submission[:name]).not_to be("")
          # Check profile link
          expect(submission[:profile]).to equal "https://www.furaffinity.net/user/#{submission[:profile_name]}/"
          # Check profile name
          expect(submission[:profile_name]).to match(@app.USER_REGEX)
        end
      end
    end

    it 'only returns SFW results, if specified'
  end

  context 'when getting user profile' do
    it 'gives valid basic profile information'
    it 'fails when given a non-existent profile'
    it 'handles square brackets in profile name'
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
end