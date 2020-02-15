
require_relative '../../lib/faexport'
require_relative 'check_helper'

require 'rspec'

describe 'FA browse parser' do

  before do
    config = File.exist?('settings-test.yml') ? YAML.load_file('settings-test.yml') : {}
    @app = FAExport::Application.new(config).instance_variable_get(:@instance)
    @fa = @app.instance_variable_get(:@fa)
    @fa.login_cookie = COOKIE_DEFAULT
  end

  after do
    # Do nothing
  end

  it 'returns a list of submissions' do
    submissions = @fa.browse({"page" => "1"})

    submissions.each do |submission|
      expect(submission).to be_valid_submission
    end
  end

  it 'returns a second page, different to the first' do
    submissions_1 = @fa.browse({"page" => "1"})
    submissions_2 = @fa.browse({"page" => "2"})

    submissions_1.each do |submission|
      expect(submission).to be_valid_submission
    end
    submissions_2.each do |submission|
      expect(submission).to be_valid_submission
    end

    expect(submissions_1).to be_different_results_to(submissions_2)
  end

  it 'defaults to 72 results' do
    submissions = @fa.browse({})

    submissions.each do |submission|
      expect(submission).to be_valid_submission
    end
    expect(submissions.length).to eql(72)
  end

  it 'returns as many submissions as perpage specifies' do
    submissions_24 = @fa.browse({"perpage" => "24"})
    submissions_48 = @fa.browse({"perpage" => "48"})
    submissions_72 = @fa.browse({"perpage" => "72"})

    expect(submissions_24.length).to eql(24)
    expect(submissions_48.length).to eql(48)
    expect(submissions_72.length).to eql(72)
  end

  it 'can specify ratings to display, and honours that selection' do
    only_adult = @fa.browse({"perpage" => 24, "rating" => "adult"})
    only_sfw_or_mature = @fa.browse({"perpage" => 24, "rating" => "mature,general"})

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