
require 'rspec'
require 'open-uri'
require 'sinatra/json'
require 'nokogiri'

describe 'FA export server' do
  COOKIE_DEFAULT = ENV['test_cookie']
  TEST_USER_2 = "fafeed-2"
  COOKIE_TEST_USER_2 = ENV['test_cookie_user_2']
  SERVER_URL = ENV['server_url']

  def fetch_with_retry(path, cookie = nil)
    wait_between_tries = 5
    retries = 0
    url = "#{SERVER_URL}/#{path}"

    begin
      resp = if cookie
        open(url, 'FA_COOKIE' => "#{cookie}")
      else
        open(url)
      end
      expect(resp.status[0]).to eq("200")
      resp
    rescue Error => e
      if (retries += 1) <= 5
        puts "Error fetching page: #{url}, #{e}, retry #{retries} in #{wait_between_tries} second(s)..."
        sleep(wait_between_tries)
        retry
      else
        raise
      end
    end
  end

  context 'when checking the home page' do
    it 'returns a webpage' do
      resp = fetch_with_retry("/")
      body = resp.read
      expect(body).not_to be_empty
      expect(body).to include("<title>FAExport</title>")
    end
  end

  context 'when checking the home.json endpoint' do
    it 'is valid json' do
      resp = fetch_with_retry("/home.json")
      body = resp.read
      expect(body).not_to be_empty
      data = JSON.parse(body)
      expect(data).to have_key("artwork")
      expect(data).to have_key("writing")
    end
  end

  context 'when checking the home.xml endpoint' do
    it 'is valid xml' do
      resp = fetch_with_retry("/home.xml")
      body = resp.read
      expect(body).not_to be_empty
      data = Nokogiri::XML(body)
      expect(data.xpath("//artwork")).not_to be_empty
      expect(data.xpath("//writing")).not_to be_empty
    end
  end

  context 'when checking a journals.rss feed' do
    it 'is valid rss' do
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
end