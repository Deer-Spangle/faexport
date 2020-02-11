
require './lib/faexport'
require_relative 'check_helper'

require 'rspec'

describe 'FA gallery parser' do
  COOKIE_DEFAULT = ENV['test_cookie']

  before do
    config = File.exist?('settings-test.yml') ? YAML.load_file('settings-test.yml') : {}
    @app = FAExport::Application.new(config).instance_variable_get(:@instance)
    @fa = @app.instance_variable_get(:@fa)
    @fa.login_cookie = COOKIE_DEFAULT
  end

  after do
    # Do nothing
  end

  %w(gallery scraps favorites).each do |folder|
    it 'returns a list of valid submission' do
      submissions = @fa.submissions(TEST_USER_2, folder, {})
      expect(submissions).to be_instance_of Array
      expect(submissions).not_to be_empty
      submissions.each do |submission|
        expect(submission).to be_valid_submission
      end
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
