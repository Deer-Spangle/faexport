# frozen_string_literal: true

require "./lib/faexport"
require_relative "check_helper"

require "rspec"

COOKIE_DEFAULT = ENV["test_cookie"]

describe "FA parser browse endpoint" do
  before do
    config = File.exist?("settings-test.yml") ? YAML.load_file("settings-test.yml") : {}
    @app = FAExport::Application.new(config).instance_variable_get(:@instance)
    cache = @app.instance_variable_get(:@cache)
    @fa = Furaffinity.new(cache)
    @fa.login_cookie = COOKIE_DEFAULT
  end

  after do
    # Do nothing
  end

  def browse_with_retry(args)
    wait_between_tries = 5
    retries = 0

    begin
      @fa.browse(args)
    rescue FAStatusError => e
      raise unless (retries += 1) <= 5

      puts "FAStatusError on Search: #{e}, retry #{retries} in #{wait_between_tries} second(s)..."
      sleep(wait_between_tries)
      retry
    end
  end

  context "when browsing" do
    it "returns a list of submissions" do
      submissions = browse_with_retry({ "page" => "1" })

      submissions.each do |submission|
        expect(submission).to be_valid_submission
      end
    end

    it "returns a second page, different to the first" do
      submissions1 = browse_with_retry({ "page" => "1" })
      submissions2 = browse_with_retry({ "page" => "2" })

      submissions1.each do |submission|
        expect(submission).to be_valid_submission
      end
      submissions2.each do |submission|
        expect(submission).to be_valid_submission
      end

      expect(submissions1).to be_different_results_to(submissions2)
    end

    it "defaults to 72 results" do
      10.times do
        submissions = browse_with_retry({})

        submissions.each do |submission|
          expect(submission).to be_valid_submission
        end
        expect(submissions.length).to be_between(68, 72)
      end
    end

    it "returns as many submissions as perpage specifies" do
      submissions24 = browse_with_retry({ "perpage" => "24" })
      submissions48 = browse_with_retry({ "perpage" => "48" })
      submissions72 = browse_with_retry({ "perpage" => "72" })

      expect(submissions24.length).to be_between(20, 24)
      expect(submissions48.length).to be_between(44, 48)
      expect(submissions72.length).to be_between(68, 72)
    end

    it "can specify ratings to display, and honours that selection" do
      only_adult = browse_with_retry({ "perpage" => 24, "rating" => "adult" })
      only_sfw_or_mature = browse_with_retry({ "perpage" => 24, "rating" => "mature,general" })

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
end
