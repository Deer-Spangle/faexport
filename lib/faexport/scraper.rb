# scraper.rb - Quick and dirty API for scraping data from FA
#
# Copyright (C) 2015 Erra Boothale <erra@boothale.net>
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

require 'net/http'
require 'nokogiri'
require 'open-uri'

USER_AGENT = 'FAExport'

class FAError < StandardError
  attr_accessor :url
  def initialize(url)
    super('Error accessing FA')
    @url = url
  end
end

class FAStatusError < FAError
  def initialize(url, status)
    super(url)
    @status = status
  end

  def to_s
    "FA returned a status of '#{@status}' while trying to access #{@url}."
  end
end

class FASystemError < FAError
  def to_s
    "FA returned a system error page when trying to access #{@url}."
  end
end

class FALoginError < FAError
  def to_s
    "Unable to log into FA to access #{@url}."
  end
end

class EmptyCache
  def add(key, expire = 0) yield; end
  def remove(key) end
end

class Furaffinity
  def initialize(cache = nil)
    @cache = cache || EmptyCache.new
  end

  def login(username, password)
    uri = URI.parse('https://www.furaffinity.net')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new('/login/')
    request.add_field('Content-Type', 'application/x-www-form-urlencoded')
    request.add_field('Origin', 'https://www.furaffinity.net')
    request.add_field('Referer', 'https://www.furaffinity.net/login/')
    request.add_field('Accept', '*/*')
    request.add_field('User-Agent', USER_AGENT)
    request.body = "action=login&retard_protection=1&name=#{username}"\
                   "&pass=#{password}&login=Login to Furaffinity"
    response = http.request(request)
    @login_cookie = "b=#{response['set-cookie'][/b=([a-z0-9\-]+);/, 1]}; a=#{response['set-cookie'][/a=([a-z0-9\-]+);/, 1]}"
  end

  def user(name)
    profile = "user/#{name}/"
    html = fetch(profile)
    info = html.css('.ldot')[0].children.to_s
    stats = html.css('.ldot')[1].children.to_s
    date = html_field(info, 'Registered since')

    {
      id: find_id(html),
      name: html.at_css('.addpad.lead b').content[1..-1],
      profile: fa_url(profile),
      account_type: html.at_css('.addpad.lead').content[/\((.+?)\)/,1].strip,
      avatar: "http:#{html.at_css('td.addpad img')['src']}",
      full_name: html_field(info, 'Full Name'),
      artist_type: html_field(info, 'Artist Type'),
      registered_since: date,
      registered_at: to_iso8601(date),
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

  def budlist(name, page, is_watchers)
    mode = is_watchers ? 'watched_by' : 'watches'
    html = fetch("user/#{name}")
    id = find_id(html)
    html = fetch("budslist/?name=#{name}&uid=#{id}&mode=#{mode}&page=#{page}")
    html.css('.artist_name').map{|elem| elem.content}
  end

  def submission(id)
    html = fetch("view/#{id}/")
    submission = html.at_css('div#submission table.maintable table.maintable')
    raw_info = submission.at_css('td.alt1')
    info = raw_info.content.lines.map{|i| i.gsub(/^\p{Space}*/, '').rstrip}
    keywords = raw_info.css('div#keywords a')
    date = pick_date(raw_info.at_css('.popup_date'))

    {
      title: html.at_css('td.cat b').content,
      description: submission.css('td.alt1')[2].children.to_s.strip,
      name: html.at_css('td.cat a').content,
      profile: fa_url(html.at_css('td.cat a')['href'][1..-1]),
      link: fa_url("view/#{id}/"),
      posted: date,
      posted_at: to_iso8601(date),
      full: "http:#{html.css('.actions a')[2]['href']}",
      thumbnail: "http:#{html.at_css('img#submissionImg')['src']}",
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

  def journal(id)
    html = fetch("journal/#{id}/")
    date = pick_date(html.at_css('td.cat .popup_date'))

    {
      title: html.at_css('td.cat b').content.gsub(/\A[[:space:]]+|[[:space:]]+\z/, ''),
      description: html.at_css('td.alt1 div.no_overflow').children.to_s.strip,
      name: html.at_css('td.cat a').content,
      profile: fa_url(html.at_css('td.cat a')['href'][1..-1]),
      link: fa_url("journal/#{id}/"),
      posted: date,
      posted_at: to_iso8601(date)
    }
  end

  def submissions(user, folder, page)
    html = fetch("#{folder}/#{user}/#{page}/")
    html.css('td.alt1 > center > b').map do |art|
      {
        id: art['id'].gsub('sid_', ''),
        title: art.at_css('span').content,
        thumbnail: "http:#{art.at_css('img')['src']}",
        link: fa_url(art.at_css('a')['href'][1..-1])
      }
    end
  end

  def journals(user)
    html = fetch("journals/#{user}/")
    journals = html.css('table.maintable table.maintable tr')[2].at_css('td td')
    journals.css('table.maintable').map do |j|
      title = j.at_css('.cat a')
      contents = j.at_css('.alt1 table')
      info = contents.at_css('.ldot table')
      date = pick_date(info.at_css('.popup_date'))
      {
        id: j['id'].gsub('jid:', ''),
        title: title.content.gsub(/\A[[:space:]]+|[[:space:]]+\z/, ''),
        description: contents.at_css('div.no_overflow').children.to_s.strip,
        link: fa_url(title['href'][1..-1]),
        posted: date,
        posted_at: to_iso8601(date)
      }
    end
  end

  def shouts(user)
    html = fetch("user/#{user}/")
    html.xpath('//table[starts-with(@id, "shout")]').map do |shout|
      name = shout.at_css('td.lead.addpad a')
      date = pick_date(shout.at_css('.popup_date'))
      {
        id: shout.attr('id'),
        name: name.content,
        profile: fa_url(name['href'][1..-1]),
        avatar: "http:#{shout.at_css('td.alt1.addpad img')['src']}",
        posted: date,
        posted_at: to_iso8601(date),
        text: shout.css('.no_overflow.alt1')[0].children.to_s.strip
      }
    end
  end

  def submission_comments(id)
    comments("view/#{id}/")
  end

  def journal_comments(id)
    comments("journal/#{id}/")
  end

private
  def fa_url(path)
    "http://www.furaffinity.net/#{path}"
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

  def pick_date(tag)
    tag.content.include?('ago') ? tag['title'] : tag.content
  end

  def to_iso8601(date)
    Time.parse(date + ' UTC').iso8601
  end

  def find_id(html)
    html.at_css('#is-watching').parent.parent.at_css('.cat > a')['href'][/uid=([0-9]+)/, 1]
  end

  def html_field(info, field)
    (info[/<b>#{field}:<\/b>(.+?)<br>/, 1] || '').gsub(%r{</?[^>]+?>}, '').strip
  end

  def html_long_field(info, field)
    (info[/<b>#{field}:<\/b><br>(.+)/m, 1] || '').strip
  end

  def fetch(path)
    url = fa_url(CGI::escape(path))
    raw = open(url, 'User-Agent' => USER_AGENT, 'Cookie' => @login_cookie) do |response|
      if response.status[0] != '200'
        raise FAStatusError.new(url, response.status.join(' ')) 
      else
        response.read
      end
    end

    html = Nokogiri::HTML(raw)

    head = html.xpath('//head//title').first
    if !head || head.content == 'System Error'
      raise FASystemError.new(url) 
    end

    page = html.to_s
    if page.include?('has elected to make their content available to registered users only.')
      raise FALoginError.new(url)
    end

    if page.include?('This user has voluntarily disabled access to their userpage.')
      raise FASystemError.new(url)
    end

    @cache.add("url:#{url}") { raw }
    html
  end

  def comments(path)
    html = fetch(path)
    comments = html.css('table.container-comment')
    comments.map do |comment|
      if comment.attr('id')
        date = pick_date(comment.at_css('.popup_date'))
        {
          id: comment.attr('id').gsub('cid:', ''),
          name: comment.at_css('.replyto-name').content.strip,
          profile: fa_url(comment.at_css('ul ul li a')['href'][1..-1]),
          avatar: "http:#{comment.at_css('.icon img')['src']}",
          posted: date,
          posted_at: to_iso8601(date),
          text: comment.at_css('.replyto-message').children.to_s.strip.gsub(/ <br><br>$/, '')
        }
      else
        nil
      end
    end.compact
  end
end
