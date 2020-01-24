require 'rspec/expectations'


RSpec::Matchers.define :be_valid_submission do |blank_profile=false, blank_title=false|
  match do |submission|
    # Check ID
    expect(submission[:id]).to match(/^[0-9]+$/)
    # Check title
    if blank_title
      expect(submission[:title]).to be_blank, "Title of submission #{submission[:id]} was not meant to be blank"
    else
      expect(submission[:title]).not_to be_blank
    end
    # Check thumbnail
    expect(submission[:thumbnail]).to be_valid_thumbnail_link_for_sub_id submission[:id]
    # Check link
    expect(submission[:link]).to be_valid_link_for_sub_id submission[:id]
    # Check profile
    if blank_profile
      expect(submission[:name]).to be_blank
      expect(submission[:profile]).to be_blank
      expect(submission[:profile_name]).to be_blank
    else
      expect(submission).to have_valid_profile_link
    end
  end
end

RSpec::Matchers.define :have_valid_profile_link do |watch_list=false|
  match do |item|
    expect(item[:name]).not_to be_blank
    expect(item[watch_list ? :link : :profile]).to eql "https://www.furaffinity.net/user/#{item[:profile_name]}/"
    expect(item[:profile_name]).to match(FAExport::Application::USER_REGEX)
  end
end

RSpec::Matchers.define :be_valid_date_and_match_iso do |iso_string|
  match do |date_string|
    expect(date_string).not_to be_blank
    expect(date_string).to match(/[A-Z][a-z]{2} [0-9]+([a-z]{2})?, [0-9]{4},? [0-9]{2}:[0-9]{2}( ?[AP]M)?/)
    expect(iso_string).not_to be_blank
    expect(iso_string).to eql(Time.parse(date_string + ' UTC').iso8601)
  end
end

RSpec::Matchers.define :be_valid_avatar_for_user do |avatar_link, username|
  /^https:\/\/a.facdn.net\/[0-9]+\/#{username}.gif$/.match(avatar_link)
end

RSpec::Matchers.define :be_valid_link_for_sub_id do |id|
  match do |link|
    /^https:\/\/www.furaffinity.net\/view\/#{id}\/?$/.match(link)
  end
end

RSpec::Matchers.define :be_valid_thumbnail_link_for_sub_id do |id|
  match do |link|
    /^https:\/\/t.facdn.net\/#{id}@[0-9]{2,3}-[0-9]+.jpg$/.match(link)
  end
end

RSpec::Matchers.define :be_similar_results_to do |result2|
  match do |results1|
    results1_ids = results1.map{|result| result[:id]}
    results2_ids = result2.map{|result| result[:id]}
    intersection = results1_ids & results2_ids

    threshold = [results1_ids.length, results2_ids.length].max * 0.9
    expect(intersection.length).to be >= threshold
  end
end

RSpec::Matchers.define :be_different_results_to do |results2|
  match do |results1|
    results1_ids = results1.map{|result| result[:id]}
    results2_ids = results2.map{|result| result[:id]}
    intersection = results1_ids & results2_ids

    threshold = [results1_ids.length, results2_ids.length].max * 0.1
    expect(intersection.length).to be <= threshold
  end
end

RSpec::Matchers.define :be_valid_status_data do
  match do |status|
    expect(status).to have_key("online")
    expect(status["online"]).to have_key("guests")
    expect(status["online"]["guests"]).to be_instance_of Integer
    expect(status["online"]).to have_key("registered")
    expect(status["online"]["registered"]).to be_instance_of Integer
    expect(status["online"]).to have_key("other")
    expect(status["online"]["other"]).to be_instance_of Integer
    expect(status["online"]).to have_key("total")
    expect(status["online"]["total"]).to be_instance_of Integer
    expect(status["online"]["total"]).to eql(status["online"]["guests"] + status["online"]["registered"] + status["online"]["other"])

    expect(status).to have_key("fa_server_time")
    expect(status["fa_server_time"]).to be_instance_of String
    expect(status["fa_server_time"]).not_to be_blank
    expect(status).to have_key("fa_server_time_at")
    expect(status["fa_server_time_at"]).to be_instance_of String
    expect(status["fa_server_time_at"]).not_to be_blank
  end
end
