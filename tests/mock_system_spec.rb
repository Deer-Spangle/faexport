# frozen_string_literal: true

require "rspec"
require "open-uri"
require "sinatra/json"
require "nokogiri"

COOKIE_DEFAULT = ENV["test_cookie"]
TEST_USER_2 = "fafeed-2"
COOKIE_TEST_USER_2 = ENV["test_cookie_user_2"]
SERVER_URL = ENV["server_url"]

describe "FA export server" do
  before(:all) do
    expect(COOKIE_DEFAULT).not_to be_empty, "Test cookie needs to be set for testing"
  end

  def spawn_static_page_server(path, status_code)
    pid = spawn("while true; do echo -ne \"HTTP/1.0 #{status_code}\n\n\"; cat  < #{path}; } | nc -q0 -vlp 3000; done")
    return pid
  end

  context "when getting a slowdown page response" do
    before do
      @pid = spawn_static_page_server("resources/slowdown_page.html", "503 Service Unavailable")
    end

    it "returns an FA slowdown error" do
      begin
        URI.parse("#{SERVER_URL}/view/123.json")
        raise "This should return an error code"
      rescue OpenURI::HTTPError => e
        e_resp = e.io
        expect(e_resp.status[0]).to eq("429")
        body = e_resp.read
        expect(body).not_to be_empty
        data = JSON.parse(body)
        expect(data).to have_key("error_type")
        expect(data["error_type"]).to eq("fa_slowdown")
      end
    end

    after do
      Process.kill("QUIT", @pid)
    end
  end

  context "when getting a cloudflare challenge response" do
    before do
      @pid = spawn_static_page_server("resources/cf_challenge.html", "403 Forbidden")
    end

    it "returns an FA slowdown error" do
      begin
        URI.parse("#{SERVER_URL}/view/123.json")
        raise "This should return an error code"
      rescue OpenURI::HTTPError => e
        e_resp = e.io
        expect(e_resp.status[0]).to eq("503")
        body = e_resp.read
        expect(body).not_to be_empty
        data = JSON.parse(body)
        expect(data).to have_key("error_type")
        expect(data["error_type"]).to eq("fa_cloudflare")
      end
    end

    after do
      Process.kill("QUIT", @pid)
    end
  end
end