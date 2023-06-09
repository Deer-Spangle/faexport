# frozen_string_literal: true

require "rspec"
require "open-uri"
require "sinatra/json"
require "nokogiri"

COOKIE_DEFAULT = ENV["test_cookie"]
TEST_USER_2 = "fafeed-2"
COOKIE_TEST_USER_2 = ENV["test_cookie_user_2"]
SERVER_URL = ENV["server_url"]
PROMETHEUS_PASS = "example_prom_pass"

describe "FA export server" do
  before(:all) do
    expect(COOKIE_DEFAULT).not_to be_empty, "Test cookie needs to be set for testing"
  end

  def fetch_with_retry(path, cookie: nil, check_status: true, user: nil, password: nil)
    wait_between_tries = 5
    retries = 0
    url = "#{SERVER_URL}/#{path}"
    user_info = nil
    if user and password
      user_info = [user, password]
    end

    begin
      if cookie
        URI.parse(url).open({ "FA_COOKIE" => cookie.to_s })
      elsif user_info
        URI.parse(url).open(:http_basic_authentication => user_info)
      else
        URI.parse(url).open
      end
    rescue OpenURI::HTTPError => e
      raise if check_status

      e.io
    rescue StandardError => e
      raise unless (retries += 1) <= 5

      puts "Error fetching page: #{url}, #{e}, retry #{retries} in #{wait_between_tries} second(s)..."
      sleep(wait_between_tries)
      retry
    end
  end

  context "when checking the home page" do
    it "returns a webpage" do
      resp = fetch_with_retry("/")
      body = resp.read
      expect(body).not_to be_empty
      expect(body).to include("<title>FAExport</title>")
    end
  end

  context "when checking the home.json endpoint" do
    it "is valid json" do
      resp = fetch_with_retry("/home.json")
      body = resp.read
      expect(body).not_to be_empty
      data = JSON.parse(body)
      expect(data).to have_key("artwork")
      expect(data).to have_key("writing")
    end
  end

  context "when checking the home.xml endpoint" do
    it "is valid xml" do
      resp = fetch_with_retry("/home.xml")
      body = resp.read
      expect(body).not_to be_empty
      data = Nokogiri::XML(body)
      expect(data.xpath("//artwork")).not_to be_empty
      expect(data.xpath("//writing")).not_to be_empty
    end
  end

  context "when checking a journals.rss feed" do
    it "is valid rss" do
      resp = fetch_with_retry("/user/#{TEST_USER_2}/journals.rss")
      body = resp.read
      expect(body).not_to be_empty
      data = Nokogiri::XML(body)
      title_elem = data.xpath("//rss/channel/title")
      expect(title_elem).not_to be_nil
      expect(title_elem[0].content).not_to be_empty
      articles = data.xpath("//rss/channel/item")
      expect(articles).not_to be_empty
      articles.each do |item|
        expect(item.at_css("title").content).not_to be_empty
        expect(item.at_css("link").content).not_to be_empty
        expect(item.at_css("description").content).not_to be_empty
        expect(item.at_css("pubDate").content).not_to be_empty
      end
    end
  end

  context "when checking restricted endpoint" do
    it "returns an error if cookie is not given" do
      resp = fetch_with_retry("/notifications/others.json", check_status: false)
      expect(resp.status[0]).to eq("401")
      expect(resp.meta["www-authenticate"]).not_to be_falsey
      body = resp.read
      expect(body).not_to be_empty
      data = JSON.parse(body)
      expect(data).to have_key("error")
      expect(data["error"]).to include("valid login cookie")
      expect(data["error"]).to include("FA_COOKIE")
    end

    it "returns data if given a cookie" do
      resp = fetch_with_retry("/notifications/others.json", cookie: COOKIE_DEFAULT)
      body = resp.read
      expect(body).not_to be_empty
      data = JSON.parse(body)
      expect(data).to have_key("current_user")
      expect(data["current_user"]).to have_key("name")
      expect(data["current_user"]["name"]).not_to be_empty
    end

    it "returns data if given basic auth" do
      a, b = COOKIE_DEFAULT.split(";")
      a = a.gsub(/[ab]=/, '')
      b = b.gsub(/[ab]=/, '')
      resp = fetch_with_retry("/notifications/others.json", user: "ab", password: "#{a};#{b}")
      body = resp.read
      expect(body).not_to be_empty
      data = JSON.parse(body)
      expect(data).to have_key("current_user")
      expect(data["current_user"]).to have_key("name")
      expect(data["current_user"]["name"]).not_to be_empty
    end

    it "returns data if given basic auth the other way around" do
      a, b = COOKIE_DEFAULT.split(";")
      a = a.gsub(/[ab]=/, '')
      b = b.gsub(/[ab]=/, '')
      resp = fetch_with_retry("/notifications/others.json", user: "ba", password: "#{b};#{a}")
      body = resp.read
      expect(body).not_to be_empty
      data = JSON.parse(body)
      expect(data).to have_key("current_user")
      expect(data["current_user"]).to have_key("name")
      expect(data["current_user"]["name"]).not_to be_empty
    end

    it "returns a different user if given a different cookie" do
      resp1 = fetch_with_retry("/notifications/others.json", cookie: COOKIE_DEFAULT)
      data1 = JSON.parse(resp1.read)

      resp2 = fetch_with_retry("/notifications/others.json", cookie: COOKIE_TEST_USER_2)
      data2 = JSON.parse(resp2.read)
      expect(data1["current_user"]["name"]).not_to be_empty
      expect(data2["current_user"]["name"]).not_to be_empty
      expect(data1["current_user"]["name"]).not_to eq(data2["current_user"]["name"])
    end
  end

  context "when checking prometheus metrics endpoint" do
    it "requires authentication" do
      resp = fetch_with_retry("/metrics", check_status: false)
      expect(resp.status[0]).to eq("401")
      expect(resp.meta["www-authenticate"]).not_to be_falsey
      expect(resp.read).not_to include("faexport_info")
    end

    it "works when auth is given" do
      resp = fetch_with_retry("/metrics", user: "prom", password: PROMETHEUS_PASS)
      expect(resp.status[0]).to eq("200")
      expect(resp.read).to include("faexport_info")
    end
  end
end
