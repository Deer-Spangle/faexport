
require './lib/faexport'
require_relative 'check_helper'

require 'rspec'

describe 'FA parser search endpoint' do
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

  def search_with_retry(args)
    wait_between_tries = 5
    retries = 0

    begin
      @fa.search(args)
    rescue FAStatusError => e
      if (retries += 1) <= 5
        puts "FAStatusError on Search: #{e}, retry #{retries} in #{wait_between_tries} second(s)..."
        sleep(wait_between_tries)
        retry
      else
        raise
      end
    end
  end

  context 'when searching submissions' do
    it 'returns a list of submission data' do
      results = search_with_retry({"q" => "YCH"})
      expect(results).to be_instance_of Array
      expect(results).not_to be_empty
      results.each do |result|
        expect(result).to be_valid_submission
      end
    end

    it 'handles blank search cleanly' do
      results = search_with_retry({q: ""})
      expect(results).to be_instance_of Array
      expect(results).to be_empty
    end

    it 'handles search queries with a space in them' do
      results = search_with_retry({"q" => "YCH deer"})
      expect(results).to be_instance_of Array
      expect(results).not_to be_empty
      results.each do |result|
        expect(result).to be_valid_submission
      end
    end

    it 'displays a different page 1 to page 2' do
      # Get page 1
      results1 = search_with_retry({"q" => "YCH"})
      expect(results1).to be_instance_of Array
      expect(results1).not_to be_empty
      # Get page 2
      results2 = search_with_retry({"q" => "YCH", "page" => "2"})
      expect(results2).to be_instance_of Array
      expect(results2).not_to be_empty
      # Check they're different enough
      expect(results1).to be_different_results_to(results2)
    end

    it 'works when making the same search twice' do
      # There was an awkward caching issue breaking this, hence this test.
      results1 = search_with_retry({"q" => "YCH"})
      expect(results1).to be_instance_of Array
      expect(results1).not_to be_empty
      expect(results1.length).to be > 20
      # Get page 2
      results2 = search_with_retry({"q" => "YCH"})
      expect(results2).to be_instance_of Array
      expect(results2).not_to be_empty
      expect(results2.length).to be > 20
    end

    it 'returns a specific set of test submissions when using a rare test keyword' do
      results = search_with_retry({"q" => "rare_test_keyword"})
      expect(results).to be_instance_of Array
      expect(results).not_to be_empty
      expect(results.length).to be 3
      result_id_list = results.map{|result| result[:id]}
      expect(result_id_list).to include("32052941")
      expect(result_id_list).to include("32057670")
      expect(result_id_list).to include("32057697")
    end

    it 'displays a number of results equal to the perpage setting' do
      results_long = search_with_retry({"q" => "YCH", "perpage" => "72"})
      expect(results_long).to be_instance_of Array
      expect(results_long).not_to be_empty
      expect(results_long.length).to be >= 70

      results_med = search_with_retry({"q" => "YCH", "perpage" => "48"})
      expect(results_med).to be_instance_of Array
      expect(results_med).not_to be_empty
      expect(results_med.length).to be >= 46
      expect(results_med.length).to be < 49

      results_short = search_with_retry({"q" => "YCH", "perpage" => "24"})
      expect(results_short).to be_instance_of Array
      expect(results_short).not_to be_empty
      expect(results_short.length).to be >= 22
      expect(results_short.length).to be < 25
    end

    it 'defaults to ordering by date desc' do
      results = search_with_retry({"q" => "YCH", "perpage" => "72"})
      expect(results).to be_instance_of Array
      expect(results).not_to be_empty
      results_date = search_with_retry({"q" => "YCH", "perpage" => "72", "order_by" => "date"})
      expect(results).to be_instance_of Array
      expect(results).not_to be_empty

      # Check they're similar enough
      expect(results).to be_similar_results_to(results_date)

      # Check it's roughly date ordered. FA results are not exactly date ordered.
      first_submission = @fa.submission(results[0][:id])
      first_datetime = Time.parse(first_submission[:posted] + ' UTC')
      last_submission = @fa.submission(results[-1][:id])
      last_datetime = Time.parse(last_submission[:posted] + ' UTC')
      expect(last_datetime).to be < first_datetime
    end

    it 'can search by relevancy and popularity, which give a different order to date' do
      results_date = search_with_retry({"q" => "YCH", "perpage" => "24", "order_by" => "date"})
      results_rele = search_with_retry({"q" => "YCH", "perpage" => "24", "order_by" => "relevancy"})
      results_popu = search_with_retry({"q" => "YCH", "perpage" => "24", "order_by" => "popularity"})
      expect(results_date).to be_different_results_to(results_rele)
      expect(results_rele).to be_different_results_to(results_popu)
      expect(results_popu).to be_different_results_to(results_date)
    end

    it 'can specify order direction as ascending' do
      results_asc = search_with_retry({"q" => "YCH", "perpage" => "24", "order_direction" => "asc"})
      results_desc = search_with_retry({"q" => "YCH", "perpage" => "24", "order_direction" => "desc"})
      expect(results_asc).to be_different_results_to(results_desc)
    end

    it 'can specify shorter range, which delivers fewer results' do
      big_results = search_with_retry({"q" => "garden", "perpage" => 72})
      expect(big_results).to be_instance_of Array
      expect(big_results).not_to be_empty
      small_results = search_with_retry({"q" => "garden", "perpage" => 72, "range" => "day"})
      expect(small_results).to be_instance_of Array
      expect(small_results).not_to be_empty

      expect(big_results.length).to be > small_results.length
    end

    it 'can specify search mode for the terms in the query' do
      extended_or_results = search_with_retry({"q" => "deer | lion", "perpage" => 72})
      extended_and_results = search_with_retry({"q" => "deer & lion", "perpage" => 72})
      or_results = search_with_retry({"q" => "deer lion", "perpage" => 72, "mode" => "any"})
      and_results = search_with_retry({"q" => "deer lion", "perpage" => 72, "mode" => "all"})

      expect(extended_and_results).to be_different_results_to(extended_or_results)
      expect(and_results).to be_different_results_to(or_results)

      expect(extended_or_results).to be_similar_results_to(or_results)
      expect(extended_and_results).to be_similar_results_to(and_results)
    end

    it 'can specify ratings to display, and honours that selection' do
      only_adult = search_with_retry({"q" => "ych", "perpage" => 24, "rating" => "adult"})
      only_sfw_or_mature = search_with_retry({"q" => "ych", "perpage" => 24, "rating" => "mature,general"})

      expect(only_adult).to be_different_results_to(only_sfw_or_mature)

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
      results = search_with_retry({"q" => "ych", "perpage" => 24, "rating" => "adult"})
      results.each do |submission|
        begin
          full_submission = @fa.submission(submission[:id])
          expect(full_submission[:rating]).to eql("General")
        rescue FASystemError
        end
      end
    end

    it 'can specify a content type for results, only returns that content type' do
      results_poem = search_with_retry({"q" => "deer", "perpage" => 72, "type" => "poetry"})
      results_photo = search_with_retry({"q" => "deer", "perpage" => 72, "type" => "photo"})
      expect(results_photo).to be_different_results_to(results_poem)
    end

    it 'can specify multiple content types for results, and only displays those types' do
      results_image = search_with_retry({"q" => "deer", "perpage" => 72, "type" => "photo,art"})
      results_swf_music = search_with_retry({"q" => "deer", "perpage" => 72, "type" => "flash,music"})
      expect(results_image).to be_different_results_to(results_swf_music)
    end

    it 'ignores other unused parameters' do
      results = search_with_retry({"q" => "ych", "foo" => "bar"})
      expect(results).to be_instance_of Array
      expect(results).not_to be_empty
    end

    it 'raises an error if given invalid option for a parameter' do
      expect { search_with_retry({"q" => "ych", "perpage" => 100}) }.to raise_error(FASearchError)
    end

    it 'raises an error if given an invalid option for a multi-value parameter' do
      expect { search_with_retry({"q" => "ych", "rating" => "adult,lewd"}) }.to raise_error(FASearchError)
    end
  end
end