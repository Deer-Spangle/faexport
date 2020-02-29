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

require 'net/http'
require 'nokogiri'
require 'open-uri'
require 'redis'
require_relative 'fetcher'
require_relative 'parsers/user_profile_parser'
require_relative 'parsers/comments_parser'
require_relative 'parsers/home_parser'
require_relative 'parsers/journal_parser'
require_relative 'parsers/notes_folder_parser'
require_relative 'parsers/note_parser'
require_relative 'errors.rb'
require_relative 'redis_cache.rb'

USER_AGENT = 'FAExport'
SEARCH_OPTIONS = {
  'perpage' => %w(24 48 72),
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
  'perpage' => 72,
  'order_by' => 'date',
  'order_direction' => 'desc',
  'range' => 'all',
  'mode' => 'extended',
  'rating' => SEARCH_OPTIONS['rating'].join(','),
  'type' => SEARCH_OPTIONS['type'].join(',')
}
SEARCH_MULTIPLE = %w(rating type)


class Furaffinity
  attr_accessor :login_cookie, :safe_for_work

  def initialize(cache)
    @cache = cache
    @safe_for_work = false
  end

  def login(username, password)
    response = post('/login/', {
      'action' => 'login',
      'retard_protection' => '1',
      'name' => username,
      'pass' => password,
      'login' => 'Login to Furaffinity'
    })
    "b=#{response['set-cookie'][/b=([a-z0-9\-]+);/, 1]}; "\
    "a=#{response['set-cookie'][/a=([a-z0-9\-]+);/, 1]}"
  end

  def home
    fetcher = Fetcher.new(@cache, @login_cookie, @safe_for_work)
    parser = HomeParser.new(fetcher)
    parser.get_result
  end

  def browse(params)
    page = params['page'] =~ /^[0-9]+$/ ? params['page'] : "1"
    perpage = SEARCH_OPTIONS['perpage'].include?(params['perpage']) ? params['perpage'] : SEARCH_DEFAULTS['perpage']
    ratings =
        if params.key?('rating') and params['rating'].gsub(' ', '').split(',').all? {|v| SEARCH_OPTIONS['rating'].include? v}
          params['rating'].gsub(' ', '').split(',')
        else
          SEARCH_DEFAULTS['rating'].split(",")
        end

    options = {
        perpage: perpage,
        rating_general: ratings.include?("general") ? 1 : 0,
        rating_mature: ratings.include?("mature") ? 1 : 0,
        rating_adult: ratings.include?("adult") ? 1 : 0
    }

    raw = @cache.add("url:browse:#{params.to_s}") do
      response = post("/browse/#{page}/", options)
      unless response.is_a?(Net::HTTPSuccess)
        raise FAStatusError.new(fa_url("/browse/#{page}/"), response.message)
      end
      response.body
    end

    # Parse browse results
    html = Nokogiri::HTML(raw)
    gallery = html.css('section#gallery-browse')

    gallery.css('figure').map{|art| build_submission(art)}
  end

  def status
    @cache.add_hash("#status", false) do
      fetcher = Fetcher.new(@cache, @login_cookie, @safe_for_work)
      html = p fetcher.fetch_html ""
      p fetcher.parse_status html
    end
  end

  def user(name)
    fetcher = Fetcher.new(@cache, @login_cookie, @safe_for_work)
    parser = UserProfileParser.new(fetcher, name)
    parser.get_result
  end

  def budlist(name, page, is_watchers)
    fetcher = Fetcher.new(@cache, @login_cookie, @safe_for_work)
    parser = WatcherListParser.new(fetcher, name, page, is_watchers)
    parser.get_result
  end

  def submission(id, is_login=false)
    url = "view/#{id}/"
    html = fetch(url)
    error_msg = html.at_css("table.maintable td.alt1")
    if !error_msg.nil? && error_msg.content.strip == "You are not allowed to view this image due to the content filter settings."
      raise FASystemError.new(url)
    end

    parse_submission_page(id, html, is_login)
  end

  def favorite_submission(id, fav_status, fav_key)
    url = "#{fav_status ? 'fav' : 'unfav'}/#{id}/?key=#{fav_key}"
    raise FAFormError.new(fa_url(url), 'fav_status') unless [true, false].include? fav_status
    raise FAFormError.new(fa_url(url), 'fav_key') unless fav_key
    raise FALoginError.new(fa_url(url)) unless login_cookie

    html = fetch(url)
    parse_submission_page(id, html, true)
  end

  def journal(id)
    fetcher = Fetcher.new(@cache, @login_cookie, @safe_for_work)
    parser = JournalParser.new(fetcher, id)
    parser.get_result
  end

  def submissions(user, folder, offset)
    fetcher = Fetcher.new(@cache, @login_cookie, @safe_for_work)
    parser = GalleryParser.new(fetcher, user, folder, offset)
    parser.get_result
  end

  def journals(user, page)
    fetcher = Fetcher.new(@cache, @login_cookie, @safe_for_work)
    parser = JournalListParser.new(fetcher, user, page)
    parser.get_result
  end

  def shouts(user)
    fetcher = Fetcher.new(@cache, @login_cookie, @safe_for_work)
    parser = ShoutsParser.new(fetcher, user)
    parser.get_result
  end

  def commissions(user)
    fetcher = Fetcher.new(@cache, @login_cookie, @safe_for_work)
    parser = CommissionInfoParser.new(fetcher, user)
    parser.get_result
  end

  def submission_comments(id, include_hidden)
    fetcher = Fetcher.new(@cache, @login_cookie, @safe_for_work)
    parser = CommentsParser.new(fetcher, :submission_comments, id, include_hidden)
    parser.get_result
  end

  def journal_comments(id, include_hidden)
    fetcher = Fetcher.new(@cache, @login_cookie, @safe_for_work)
    parser = CommentsParser.new(fetcher, :journal_comments, id, include_hidden)
    parser.get_result
  end

  # Also returns the URI of the search
  def search(options = {})
    if options['q'].blank?
      return []
    end

    options = SEARCH_DEFAULTS.merge(options)
    params = {}

    # Handle page specification
    page = options['page']
    if page !~ /[0-9]+/ || page.to_i <= 1
      options['page'] = 1
      params['do_search'] = 'Search'
    else
      options['page'] = options['page'].to_i - 1
      params['next_page'] = ">>> #{options['perpage']} more >>>"
    end

    # Construct params, to send in POST request
    options.each do |key, value|
      name = key.gsub('_','-')
      if SEARCH_MULTIPLE.include? key
        values = options[key].gsub(' ', '').split(',')
        raise FASearchError.new(key, options[key], fa_url('search')) unless values.all?{|v| SEARCH_OPTIONS[key].include? v}
        values.each{|v| params["#{name}-#{v}"] = 'on'}
      elsif SEARCH_OPTIONS.keys.include? key
        raise FASearchError.new(key, options[key], fa_url('search')) unless SEARCH_OPTIONS[key].include? options[key].to_s
        params[name] = value
      elsif SEARCH_DEFAULTS.keys.include? key
        params[name] = value
      end
    end

    # Get search response
    raw = @cache.add("url:search:#{params.to_s}") do
      response = post('/search/', params)
      unless response.is_a?(Net::HTTPSuccess)
        raise FAStatusError.new(fa_url('search/'), response.message)
      end
      response.body
    end
    # Parse search results
    html = Nokogiri::HTML(raw)
    # Get search results. Even a search with no matches gives this div.
    results = html.at_css("#search-results")
    # If form fails to submit, this div will not be there.
    if results.nil?
      raise FAFormError.new(fa_url('/search/'))
    end
    html.css('.gallery > figure').map{|art| build_submission(art)}
  end

  def submit_journal(title, description)
    url = 'controls/journal/'
    raise FAFormError.new(fa_url(url), 'title') unless title
    raise FAFormError.new(fa_url(url), 'description') unless description
    raise FALoginError.new(fa_url(url)) unless login_cookie

    html = fetch(url)
    key = html.at_css('input[name="key"]')['value']
    response = post('/controls/journal/', {
      'id' => '',
      'key' => key,
      'do' => 'update',
      'subject' => title,
      'message' => description
    })
    unless response.is_a?(Net::HTTPMovedTemporarily)
      raise FAFormError.new(fa_url('controls/journal/'))
    end

    {
      url: fa_url(response['location'][1..-1])
    }
  end

  def new_submissions(from_id)
    fetcher = Fetcher.new(@cache, @login_cookie, @safe_for_work)
    parser = NewSubmissionsParser.new(fetcher, from_id)
    parser.get_result(@login_cookie)  # TODO: Neaten when refactor pulls fetcher out.
  end

  def notifications(include_deleted)
    fetcher = Fetcher.new(@cache, @login_cookie, @safe_for_work)
    parser = NotificationsParser.new(fetcher, include_deleted)
    parser.get_result(@login_cookie)  # TODO
  end

  def notes(folder)
    fetcher = Fetcher.new(@cache, @login_cookie, @safe_for_work)
    parser = NotesFolderParser.new(fetcher, folder, 1)
    parser.get_result
  end

  def note(id)
    fetcher = Fetcher.new(@cache, @login_cookie, @safe_for_work)
    parser = NoteParser.new(fetcher, id)
    parser.get_result
  end

  def fa_url(path)
    path = strip_leading_slash(path)
    "#{fa_address}/#{path}"
  end

  def strip_leading_slash(path)
    while path.to_s.start_with? "/"
      path = path[1..-1]
    end
    path
  end

private
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
    "https://#{safe_for_work ? 'sfw' : 'www'}.furaffinity.net"
  end

  def last_path(path)
    path.split('/').last
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

  def fetch(path, extra_cookie = nil)

    fetcher = Fetcher.new(@cache, @login_cookie, @safe_for_work)
    html = fetcher.fetch_html(path, extra_cookie)
    style = fetcher.identify_style(html)
    if style != :style_classic
      raise FAStyleError.new(path)
    end

    html
  end

  def post(path, params)
    uri = URI.parse(fa_fetch_address)
    http = Net::HTTP.new(uri.host, uri.port)
    unless ENV["CF_BYPASS"] or ENV["CF_BYPASS_SFW"]
      http.use_ssl = true
    end
    request = Net::HTTP::Post.new(path)
    request.add_field('Content-Type', 'application/x-www-form-urlencoded')
    request.add_field('Origin', fa_address)
    request.add_field('Referer', fa_address + path)
    request.add_field('Accept', '*/*')
    request.add_field('User-Agent', USER_AGENT)
    request.add_field('Cookie', @login_cookie)
    request.form_data = params
    http.request(request)
  end

  def build_submission(elem)
    if elem
      id = elem['id']
      title =
        if elem.at_css('figcaption')
          elem.at_css('figcaption').at_css('p').at_css('a').content
        elsif elem.at_css('span')
          elem.at_css('span').content
        else
          ""
        end
      author_elem = elem.at_css('figcaption') ? elem.at_css('figcaption').css('p')[1].at_css('a') : nil
      sub = {
        id: id ? id.gsub(/sid[-_]/, '') : '',
        title: title,
        thumbnail: "https:#{elem.at_css('img')['src']}",
        link: fa_url(elem.at_css('a')['href'][1..-1]),
        name: author_elem ? author_elem.content : '',
        profile: author_elem ? fa_url(author_elem['href'][1..-1]) : '',
        profile_name: author_elem ? last_path(author_elem['href']) : ''
      }
      sub[:fav_id] = elem['data-fav-id'] if elem['data-fav-id']
      sub
    else
      nil
    end
  end

  def build_submission_notification(elem)
    title_link = elem.css('a')[1]
    uploader_link = elem.css('a')[2]
    {
      id: last_path(title_link['href']),
      title: title_link.content.to_s,
      thumbnail: "https:#{elem.at_css('img')['src']}",
      link: fa_url(title_link['href'][1..-1]),
      name: uploader_link.content.to_s,
      profile: fa_url(uploader_link['href'][1..-1]),
      profile_name: last_path(uploader_link['href'])
    }
  end

  def parse_submission_page(id, html, is_login)
    submission = html.css('div#page-submission table.maintable table.maintable')[-1]
    submission_title = submission.at_css(".classic-submission-title")
    raw_info = submission.at_css('td.alt1')
    info = raw_info.content.lines.map{|i| i.gsub(/^\p{Space}*/, '').rstrip}
    keywords = raw_info.css('div#keywords a')
    date = pick_date(raw_info.at_css('.popup_date'))
    img = html.at_css('img#submissionImg')
    actions_bar = html.css('#page-submission td.alt1 div.actions a')
    download_url = "https:" + actions_bar.select {|a| a.content == "Download" }.first['href']
    profile_url = html.at_css('td.cat a')['href'][1..-1]
    og_thumb = html.at_css('meta[property="og:image"]')
    thumb_img = if og_thumb.nil? || og_thumb['content'].include?("/banners/fa_logo")
                  img ? "https:" + img['data-preview-src'] : nil
                else
                  og_thumb['content'].sub! "http:", "https:"
                end

    submission = {
        title: submission_title.at_css('h2').content,
        description: submission.css('td.alt1')[2].children.to_s.strip,
        description_body: submission.css('td.alt1')[2].children.to_s.strip,
        name: html.css('td.cat a')[1].content,
        profile: fa_url(profile_url),
        profile_name: last_path(profile_url),
        avatar: "https:#{submission_title.at_css("img.avatar")['src']}",
        link: fa_url("view/#{id}/"),
        posted: date,
        posted_at: to_iso8601(date),
        download: download_url,
        full: img ? "https:" + img['data-fullview-src'] : nil,
        thumbnail: thumb_img,
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

    if is_login
      fav_link = actions_bar.select {|a| a.content.end_with? "Favorites" }.first
      fav_status = fav_link.content.start_with?("-Remove")
      fav_key = fav_link['href'].split("?key=")[-1]

      submission[:fav_status] = fav_status
      submission[:fav_key] = fav_key
    end

    submission
  end
end
