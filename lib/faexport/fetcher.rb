# encoding: utf-8

# scraper.rb - Quick and dirty API for scraping data from FA
#
# Copyright (C) 2015 Erra Boothale <erra@boothale.net>
# Further work: 2020 Deer Spangle <deer@spangle.org.uk>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#   * Redistributions of source code must retain the above copyright notice,
#     this list of conditions and the following disclaimer.
#   * Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
#   * Neither the name of FAExport nor the names of its contributors may be
#     used to endorse or promote products derived from this software without
#     specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

:style_unknown
:style_classic
:style_modern

class Fetcher
  attr_accessor :cache, :cookie, :safe_for_work

  def initialize(cache, cookie, safe_for_work)
    @cache = cache
    @cookie = cookie
    @safe_for_work = safe_for_work
  end

  def fetch_html(path, extra_cookie = nil)
    url = fetch_url(path)
    raw = @cache.add("url:#{url}:#{@cookie}:#{extra_cookie}") do
      open(url, 'User-Agent' => USER_AGENT, 'Cookie' => "#{@cookie};#{extra_cookie}") do |response|
        if response.status[0] != '200'
          raise FAStatusError.new(url, response.status.join(' '))
        end
        response.read.encode('UTF-8', :invalid => :replace, :undef => :replace)
      end
    end

    html = Nokogiri::HTML(raw)

    head = html.xpath('//head//title').first
    if !head || head.content == 'System Error'
      raise FASystemError.new(url)
    end

    if raw.include?('has elected to make their content available to registered users only.')
      raise FALoginError.new(url)
    end

    if raw.include?('has voluntarily disabled access to their account and all of its contents.')
      raise FASystemError.new(url)
    end

    if raw.include?('<a href="/register"><strong>Create an Account</strong></a>')
      raise FALoginError.new(url)
    end

    # Parse and save the status, most pages have this, but watcher lists do not.
    @cache.add_hash("#status", false) do
      parse_status html
    end

    html
  end

  def fetch_url(path)
    path = strip_leading_slash(path)
    "#{fa_fetch_address}/#{path}"
  end

  def fa_fetch_address
    if ENV["CF_BYPASS_SFW"] and @safe_for_work
      ENV["CF_BYPASS_SFW"]
    elsif ENV["CF_BYPASS"]
      ENV["CF_BYPASS"]
    else
      fa_address
    end
  end

  def fa_address
    "https://#{@safe_for_work ? 'sfw' : 'www'}.furaffinity.net"
  end

  def strip_leading_slash(path)
    while path.to_s.start_with? "/"
      path = path[1..-1]
    end
    path
  end

  def parse_status(html)
    footer = html.css('.footer')
    center = footer.css('center')

    if footer.length == 0
      return
    end
    timestamp_line = footer[0].inner_html.split("\n").select{|line| line.strip.start_with? "Server Local Time: "}
    timestamp = timestamp_line[0].to_s.split("Time:")[1].strip

    counts = center.to_s.scan(/([0-9]+)\s*<b>/).map{|d| d[0].to_i}

    {
        online: {
            guests: counts[1],
            registered: counts[2],
            other: counts[3],
            total: counts[0]
        },
        fa_server_time: timestamp,
        fa_server_time_at: to_iso8601(timestamp)
    }
  rescue
    # If we fail to read and save status, it's no big deal
  end

  def to_iso8601(date)
    Time.parse(date + ' UTC').iso8601
  end

  def identify_style(html)
    stylesheet = html.at_css("head link[rel='stylesheet']")["href"]
    if stylesheet.start_with?("/themes/classic/")
      :style_classic
    elsif stylesheet.start_with?("/themes/beta")
      :style_modern
    else
      :style_unknown
    end
  end
end
