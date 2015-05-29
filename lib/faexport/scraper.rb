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
SEARCH_OPTIONS = {
  'perpage' => %w(24 36 48 60),
  'order_by' => %w(relevancy date popularity),
  'order_direction' => %w(asc desc),
  'range' => %w(day 3days week month all),
  'mode' => %w(all any extended),
  'rating' => %w(general mature adult),
  'type' => %w(art flash photo music story poetry)
}
SEARCH_DEFAULTS = {
  'q' => '',
  'page' => 1,
  'perpage' => 60,
  'order_by' => 'date',
  'order_direction' => 'desc',
  'range' => 'all',
  'mode' => 'extended',
  'rating' => SEARCH_OPTIONS['rating'].join(','),
  'type' => SEARCH_OPTIONS['type'].join(',')
}
SEARCH_MULTIPLE = [
  'rating',
  'type'
]

class FAError < StandardError
  attr_accessor :url
  def initialize(url)
    super('Error accessing FA')
    @url = url
  end
end

class FASearchError < FAError
  def initialize(key, value)
    super('http://www.furaffinity.net/search/')
    @key = key
    @value = value
  end

  def to_s
    field = @key.to_s
    multiple = SEARCH_MULTIPLE.include?(@key) ? 'zero or more' : 'one'
    options = SEARCH_OPTIONS[@key].join(', ')
    "The search field #{field} must contain #{multiple} of: #{options}.  You provided: #{@value}"
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
  attr_accessor :login_cookie

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
    profile = "user/#{escape(name)}/"
    html = fetch(profile)
    info = html.css('.ldot')[0].children.to_s
    stats = html.css('.ldot')[1].children.to_s
    date = html_field(info, 'Registered since')
    tables = {}
    html.css('table.maintable').each do |table|
      title = table.at_css('td.cat b')
      tables[title.content.strip] = table.at_css('td.alt1') if title
    end

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
      favorites: html_field(stats, 'Favorites'),
      featured_submission: build_submission(html.at_css('#featured-submission b')),
      profile_id: build_submission(html.at_css('#profilepic-submission b')),
      artist_information: select_artist_info(tables['Artist Information']),
      contact_information: select_contact_info(tables['Contact Information'])
    }
  end

  def budlist(name, page, is_watchers)
    mode = is_watchers ? 'watched_by' : 'watches'
    html = fetch("user/#{escape(name)}")
    id = find_id(html)
    html = fetch("budslist/?name=#{escape(name)}&uid=#{id}&mode=#{mode}&page=#{page}")
    html.css('.artist_name').map{|elem| elem.content}
  end

  def submission(id)
    html = fetch("view/#{id}/")
    submission = html.at_css('div#submission table.maintable table.maintable')
    raw_info = submission.at_css('td.alt1')
    info = raw_info.content.lines.map{|i| i.gsub(/^\p{Space}*/, '').rstrip}
    keywords = raw_info.css('div#keywords a')
    date = pick_date(raw_info.at_css('.popup_date'))
    thumbnail = html.at_css('img#submissionImg')

    {
      title: html.at_css('td.cat b').content,
      description: submission.css('td.alt1')[2].children.to_s.strip,
      name: html.at_css('td.cat a').content,
      profile: fa_url(html.at_css('td.cat a')['href'][1..-1]),
      link: fa_url("view/#{id}/"),
      posted: date,
      posted_at: to_iso8601(date),
      full: "http:#{html.css('.actions b a')[1]['href']}",
      thumbnail: thumbnail ? "http:#{thumbnail['src']}" : '',
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
    html = fetch("#{folder}/#{escape(user)}/#{page}/")
    html.css('td.alt1 > center > b').map {|art| build_submission(art)}
  end

  def journals(user)
    html = fetch("journals/#{escape(user)}/")
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
    html = fetch("user/#{escape(user)}/")
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

  def commissions(user)
    html = fetch("commissions/#{escape(user)}")
    unless html.at_css('#no-images')
      html.css('table.types-table tr').map do |com|
        {
          title: com.at_css('.info dt').content.strip,
          price: com.at_css('.info dd span').next.content.strip,
          description: com.at_css('.desc').children.to_s.strip,
          submission: build_submission(com.at_css('b'))
        }
      end
    else
      []
    end
  end

  def submission_comments(id, include_hidden)
    comments("view/#{id}/", include_hidden)
  end

  def journal_comments(id, include_hidden)
    comments("journal/#{id}/", include_hidden)
  end

  def search(options = {})
    if options['q'].blank?
      return []
    end

    options = SEARCH_DEFAULTS.merge(options)

    page = options['page']
    if page !~ /[0-9]+/ || page.to_i <= 1
      options['page'] = 1
      submit_mode = "&do_search=Search"
    else
      options['page'] = options['page'].to_i - 1
      submit_mode = "&next_page=>>> #{options['perpage']} more >>>"
    end

    params = options.map do |key, value|
      name = key.gsub('_','-')
      if SEARCH_MULTIPLE.include? key
        values = options[key].gsub(' ', '').split(',')
        raise FASearchError.new(key, options[key]) unless values.all?{|v| SEARCH_OPTIONS[key].include? v}
        values.map{|v| "#{name}-#{v}=on"}
      elsif SEARCH_OPTIONS.keys.include? key
        raise FASearchError.new(key, options[key]) unless SEARCH_OPTIONS[key].include? options[key].to_s
        "#{name}=#{value}"
      elsif SEARCH_DEFAULTS.keys.include? key
        "#{name}=#{value}"
      else
        []
      end
    end.flatten

    uri = URI.parse('http://www.furaffinity.net')
    request = Net::HTTP::Post.new('/search/')
    request.add_field('Content-Type', 'application/x-www-form-urlencoded')
    request.add_field('Origin', 'http://www.furaffinity.net')
    request.add_field('Referer', 'http://www.furaffinity.net/search/')
    request.add_field('Accept', '*/*')
    request.add_field('User-Agent', USER_AGENT)
    request.add_field('Cookie', @login_cookie)
    request.body = params.join('&') + submit_mode

    raw = @cache.add("url:serach:#{request.body}") do
      response = Net::HTTP.start(uri.host, uri.port) {|http| http.request(request)}
      unless response.is_a?(Net::HTTPSuccess)
        raise FAStatusError.new(fa_url('/search/'), response.message)
      end
      response.body
    end

    html = Nokogiri::HTML(raw)
    html.css('.search > b').map{|art| build_submission(art)}
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

  def select_artist_info(elem)
    return nil unless elem
    info = {}
    elem.children.to_s.scan(/<span>\s*(.*?)\s*<\/span>\s*:\s*(.*?)\s*<br\/?>/).each do |match|
      info[match[0]] = match[1]
    end
    info
  end

  def select_contact_info(elem)
    return nil unless elem
    elem.css('tr').map do |tr|
      link_elem = tr.at_css('a')
      {
        title: tr.at_css('strong').content.gsub(/:\s*$/, ''),
        name: (link_elem || tr.at_css('td')).content.strip,
        link: link_elem ? link_elem['href'] : ''
      }
    end
  end

  def escape(name)
    CGI::escape(name)
  end

  def fetch(path)
    url = fa_url(path)
    raw = @cache.add("url:#{url}") do
      open(url, 'User-Agent' => USER_AGENT, 'Cookie' => @login_cookie) do |response|
        if response.status[0] != '200'
          raise FAStatusError.new(url, response.status.join(' '))
        end
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

    html
  end

  def build_submission(elem)
    if elem
      id = elem['id']
      title_elem = elem.at_css('span')
      {
        id: id ? id.gsub('sid_', '') : '',
        title: title_elem ? title_elem.content : '',
        thumbnail: "http:#{elem.at_css('img')['src']}",
        link: fa_url(elem.at_css('a')['href'][1..-1])
      }
    else
      nil
    end
  end

  def comments(path, include_hidden)
    html = fetch(path)
    comments = html.css('table.container-comment')
    reply_stack = []
    comments.map do |comment|
      has_id = !!comment.attr('id')
      id = has_id ? comment.attr('id').gsub('cid:', '') : 'hidden'
      width = comment.attr('width')[0..-2].to_i

      while reply_stack.any? && reply_stack.last[:width] <= width
        reply_stack.pop
      end
      reply_to = reply_stack.any? ? reply_stack.last[:id] : ''
      reply_level = reply_stack.size
      reply_stack.push({id: id, width: width})

      if has_id
        date = pick_date(comment.at_css('.popup_date'))
        {
          id: id,
          name: comment.at_css('.replyto-name').content.strip,
          profile: fa_url(comment.at_css('ul ul li a')['href'][1..-1]),
          avatar: "http:#{comment.at_css('.icon img')['src']}",
          posted: date,
          posted_at: to_iso8601(date),
          text: comment.at_css('.replyto-message').children.to_s.strip.gsub(/ <br><br>$/, ''),
          reply_to: reply_to,
          reply_level: reply_level
        }
      elsif include_hidden
        {
          text: comment.at_css('strong').content,
          reply_to: reply_to,
          reply_level: reply_level
        }
      else
        nil
      end
    end.compact
  end
end
