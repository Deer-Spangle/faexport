# scraper.rb - Quick and dirty API for scraping data from FA
#
# Copyright (C) 2015 Boothale <boothale@gmail.com>
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

require 'nokogiri'
require 'open-uri'
require 'net/http'
require 'yaml'
require 'benchmark'

USER_AGENT = 'FAExport'
SETTINGS_FILE = 'settings.yml'
if File.exist?('settings.yml')
  SETTINGS = YAML.load_file('settings.yml')
else
  SETTINGS = { 'username' => ENV['FA_USERNAME'], 'password' => ENV['FA_PASSWORD'] }
end

class FAError < StandardError
  attr_accessor :url
  def initialize(url)
    super('Error accessing FA')
    @url = url
  end
end

def fa_url(path)
  "http://www.furaffinity.net/#{path}"
end

def fa_login
  uri = URI.parse('https://www.furaffinity.net')
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  request = Net::HTTP::Post.new('/login/')
  request.add_field('Content-Type', 'application/x-www-form-urlencoded')
  request.add_field('Origin', 'https://www.furaffinity.net')
  request.add_field('Referer', 'https://www.furaffinity.net/login/')
  request.add_field('Accept', '*/*')
  request.add_field('User-Agent', USER_AGENT)
  request.body = "action=login&retard_protection=1&name=#{SETTINGS['username']}"\
                 "&pass=#{SETTINGS['password']}&login=Login to Furaffinity"
  response = http.request(request)
  @login_cookie = "b=#{response['set-cookie'][/b=([a-z0-9\-]+);/, 1]}; a=#{response['set-cookie'][/a=([a-z0-9\-]+);/, 1]}"
end

def fa_open(path)
  fa_login unless @login_cookie
  url = fa_url(path)
  raw = open(url,
             'User-Agent' => USER_AGENT,
             'Cookie' => @login_cookie)
  html = Nokogiri::HTML(raw)
  raise FAError(url) if html.xpath('//head//title').first.content == 'System Error'
  html
end

def field(info, field)
  # Most often, fields just show up in the format "Field: value"
  value = info.map{|i| i[/^#{field}: (.+)$/, 1]}.compact.first
  return value if value

  # However, they also can be "Field:" "value"
  info.each_with_index do |i, index|
    return info[index + 1] if i =~ /^#{field}:$/
  end
  nil
end

def html_field(info, field)
  (info[/<b>#{field}:<\/b>(.+?)<br>/, 1] || '').gsub(%r{</?[^>]+?>}, '').strip
end

def html_long_field(info, field)
  (info[/<b>#{field}:<\/b><br>(.+)/m, 1] || '').strip
end

def open_user(name)
  html = fa_open("user/#{name}/")
  info = html.css('.ldot')[0].children.to_s
  stats = html.css('.ldot')[1].children.to_s
  {
    name: name,
    full_name: html_field(info, 'Full Name'),
    artist_type: html_field(info, 'Artist Type'),
    registered_since: html_field(info, 'Registered since'),
    current_mood: html_field(info, 'Current mood'),
    artist_profile: html_long_field(info, 'Artist Profile'),
    pageviews: html_field(stats, 'Pageviews'),
    submissions: html_field(stats, 'Submissions'),
    comments_received: html_field(stats, 'Comments Received'),
    comments_given: html_field(stats, 'Comments Given'),
    journals: html_field(stats, 'Journals'),
    favorites: html_field(stats, 'Favorites')
  }
end

def open_submission(id)
  html = fa_open("view/#{id}/")
  submission = html.css('div#submission table.maintable table.maintable')[1]
  raw_info = submission.css('td.alt1')[1]
  info = raw_info.content.lines.map{|i| i.gsub(/^\p{Space}*/, '').rstrip}
  keywords = raw_info.css('div#keywords a')

  {
    title: html.at_css('td.cat b').content,
    description: submission.css('td.alt1')[2].children.to_s.strip,
    link: fa_url("view/#{id}/"),
    posted: raw_info.at_css('span').content,
    image: "http:#{html.at_css('img#submissionImg')['src']}",
    category: field(info, 'Category'),
    theme: field(info, 'Theme'),
    species: field(info, 'Species'),
    gender: field(info, 'Gender'),
    favorites: field(info, 'Favorites'),
    comments: field(info, 'Comments'),
    views: field(info, 'Views'),
    resolution: field(info, 'Resolution'),
    rating: raw_info.at_css('div img')['alt'].gsub(' rating', ''),
    keywords: keywords ? keywords.map(&:content).reject(&:empty?) : []
  }
end

def open_journal(id)
  html = fa_open("journal/#{id}/")
  {
    title: html.at_css('td.cat b').content.strip,
    description: html.at_css('td.alt1 div.no_overflow').children.to_s.strip,
    link: fa_url("journal/#{id}/"),
    posted: html.at_css('td.cat span')['title']
  }
end

def list_submissions(user, area, max_pages = 10)
  submissions = []
  (1..max_pages).each do |page|
    html = fa_open("#{area}/#{user}/#{page}/")
    found = html.css('td.alt1 b.t-image').map do |art|
      art['id'].gsub('sid_', '')
    end
    break if found.empty?
    submissions.push(*found)
  end
  submissions
end

def list_journals(user)
  html = fa_open("journals/#{user}/")
  journals = html.css('table.maintable table.maintable tr')[2].at_css('td td')
  journals.css('table.maintable').map{|j| j['id'].gsub('jid:', '')}
end

def list_shouts(user)
  html = fa_open("user/#{user}/")
  html.xpath('//table[starts-with(@id, "shout")]').map do |shout|
    {
      id: shout.attr('id'),
      name: shout.css('.lead.addpad a')[0].content,
      posted: shout.css('.popup_date')[0].content,
      text: shout.css('.no_overflow.alt1')[0].children.to_s.strip
    }
  end
end

