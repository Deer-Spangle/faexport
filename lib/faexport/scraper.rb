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
    if offset.size > 1
      raise FAOffsetError.new(
        fa_url("#{folder}/#{escape(user)}/"),
        "You may only provide one of 'page', 'next' or 'prev' as a parameter")
    elsif folder == 'favorites' && offset[:page]
      raise FAOffsetError.new(
        fa_url("#{folder}/#{escape(user)}/"),
        "Due to a change by Furaffinity, favorites can no longer be accessed by page. See http://faexport.boothale.net/docs#get-user-name-folder for more details.")
    elsif folder != 'favorites' && (offset[:next] || offset[:prev])
      raise FAOffsetError.new(
        fa_url("#{folder}/#{escape(user)}/"),
        "The options 'next' and 'prev' are only usable on favorites. Use 'page' instead with a page number")
    end
    
    url = if offset[:page]
      "#{folder}/#{escape(user)}/#{offset[:page]}/"
    elsif offset[:next]
      "#{folder}/#{escape(user)}/#{offset[:next]}/next"
    elsif offset[:prev]
      "#{folder}/#{escape(user)}/#{offset[:prev]}/prev"
    else
      "#{folder}/#{escape(user)}/"
    end

    html = fetch(url)
    error_msg = html.at_css("table.maintable td.alt1 b")
    if !error_msg.nil? &&
      (error_msg.text == "The username \"#{user}\" could not be found." ||
          error_msg.text == "User \"#{user}\" was not found in our database.")
      raise FASystemError.new(url)
    end

    html.css('.gallery > figure').map {|art| build_submission(art)}
  end

  def journals(user, page)
    html = fetch("journals/#{escape(user)}/#{page}")
    html.xpath('//table[starts-with(@id, "jid")]').map do |j|
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
      profile_url = name['href'][1..-1]
      {
        id: shout.attr('id'),
        name: name.content,
        profile: fa_url(profile_url),
        profile_name: last_path(profile_url),
        avatar: "https:#{shout.at_css('td.alt1.addpad img')['src']}",
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
    # Set pagination
    url = "msg/submissions/new"
    if from_id
      url << "~#{from_id}@72/"
    end

    # Get page code
    html = fetch(url)

    login_user = get_current_user(html, url)
    submissions = html.css('.gallery > figure').map{|art| build_submission_notification(art)}
    {
        "current_user": login_user,
        "new_submissions": submissions
    }
  end

  def notifications(include_deleted)
    # Get page code
    url = "msg/others/"
    html = fetch(url)
    # Parse page
    login_user = get_current_user(html, url)
    # Parse notification totals
    num_submissions = 0
    num_comments = 0
    num_journals = 0
    num_favorites = 0
    num_watchers = 0
    num_notes = 0
    num_trouble_tickets = 0
    totals = html.css("a.notification-container").each do |elem|
      count = Integer(elem['title'].gsub(",", "").split()[0])
      if elem['title'].include? "Submission"
        num_submissions = count
      elsif elem['title'].include? "Comment"
        num_comments = count
      elsif elem['title'].include? "Journal"
        num_journals = count
      elsif elem['title'].include? "Favorite"
        num_favorites = count
      elsif elem['title'].include? "Watch"
        num_watchers = count
      elsif elem['title'].include? "Unread Notes"
        num_notes = count
      else
        num_trouble_tickets = count
      end
    end
    # Parse new watcher notifications
    new_watches = []
    watches_elem = html.at_css("ul#watches")
    if watches_elem
      watches_elem.css("li:not(.section-controls)").each do |elem|
        if elem.at_css("input")['checked'] == "checked"
          if include_deleted
            new_watches << {
                watch_id: "",
                name: "Removed by the user",
                profile: "",
                profile_name: "",
                avatar: fa_url(elem.at_css("img")['src']),
                posted: "",
                posted_at: ""
            }
          end
          next
        end
        date = pick_date(elem.at_css('.popup_date'))
        new_watches << {
            watch_id: elem.at_css("input")['value'],
            name: elem.at_css("span").content,
            profile: fa_url(elem.at_css("a")['href']),
            profile_name: last_path(elem.at_css("a")['href']),
            avatar: "https:#{elem.at_css("img")['src']}",
            posted: date,
            posted_at: to_iso8601(date)
        }
      end
    end
    # Parse new submission comments notifications
    new_submission_comments = []
    submission_comments_elem = html.at_css("fieldset#messages-comments-submission")
    if submission_comments_elem
      submission_comments_elem.css("li:not(.section-controls)").each do |elem|
        if elem.at_css("input")['checked'] == "checked"
          if include_deleted
            new_submission_comments << {
                comment_id: "",
                name: "Comment or the submission it was left on has been deleted",
                profile: "",
                profile_name: "",
                is_reply: false,
                your_submission: false,
                their_submission: false,
                submission_id: "",
                title: "Comment or the submission it was left on has been deleted",
                posted: "",
                posted_at: ""
            }
          end
          next
        end
        elem_links = elem.css("a")
        date = pick_date(elem.at_css('.popup_date'))
        is_reply = elem.to_s.include?("<em>your</em> comment on")
        new_submission_comments << {
            comment_id: elem.at_css("input")['value'],
            name: elem_links[0].content,
            profile: fa_url(elem_links[0]['href']),
            profile_name: last_path(elem_links[0]['href']),
            is_reply: is_reply,
            your_submission: !is_reply || elem.css('em').length == 2 && elem.css('em').last.content == "your",
            their_submission: elem.css('em').last.content == "their",
            submission_id: elem_links[1]['href'].split("/")[-2],
            title: elem_links[1].content,
            posted: date,
            posted_at: to_iso8601(date)
        }
      end
    end
    # Parse new journal comments notifications
    new_journal_comments = []
    journal_comments_elem = html.at_css("fieldset#messages-comments-journal")
    if journal_comments_elem
      journal_comments_elem.css("li:not(.section-controls)").each do |elem|
        if elem.at_css("input")['checked'] == "checked"
          if include_deleted
            new_journal_comments << {
                comment_id: "",
                name: "Comment or the journal it was left on has been deleted",
                profile: "",
                profile_name: "",
                is_reply: false,
                your_journal: false,
                their_journal: false,
                journal_id: "",
                title: "Comment or the journal it was left on has been deleted",
                posted: "",
                posted_at: ""
            }
          end
          next
        end
        elem_links = elem.css("a")
        date = pick_date(elem.at_css('.popup_date'))
        is_reply = elem.to_s.include?("<em>your</em> comment on")
        new_journal_comments << {
            comment_id: elem.at_css("input")['value'],
            name: elem_links[0].content,
            profile: fa_url(elem_links[0]['href']),
            profile_name: last_path(elem_links[0]['href']),
            is_reply: is_reply,
            your_journal: !is_reply || elem.css('em').length == 2 && elem.css('em').last.content == "your",
            their_journal: elem.css('em').last.content == "their",
            journal_id: elem_links[1]['href'].split("/")[-2],
            title: elem_links[1].content,
            posted: date,
            posted_at: to_iso8601(date)
        }
      end
    end
    # Parse new shout notifications
    new_shouts = []
    shouts_elem = html.at_css("fieldset#messages-shouts")
    if shouts_elem
      shouts_elem.css("li:not(.section-controls)").each do |elem|
        if elem.at_css("input")['checked'] == "checked"
          if include_deleted
            new_shouts << {
                shout_id: "",
                name: "Shout has been removed from your page",
                profile: "",
                profile_name: "",
                posted: "",
                posted_at: ""
            }
          end
          next
        end
        date = pick_date(elem.at_css('.popup_date'))
        new_shouts << {
            shout_id: elem.at_css("input")['value'],
            name: elem.at_css("a").content,
            profile: fa_url(elem.at_css("a")['href']),
            profile_name: last_path(elem.at_css("a")['href']),
            posted: date,
            posted_at: to_iso8601(date)
        }
      end
    end
    # Parse new favourite notifications
    new_favorites = []
    favorites_elem = html.at_css("ul#favorites")
    if favorites_elem
      favorites_elem.css("li:not(.section-controls)").each do |elem|
        if elem.at_css("input")['checked'] == "checked"
          if include_deleted
            new_favorites << {
                favorite_notification_id: "",
                name: "The favorite this notification was for has since been removed by the user",
                profile: "",
                profile_name: "",
                submission_id: "",
                submission_name: "The favorite this notification was for has since been removed by the user",
                posted: "",
                posted_at: ""
            }
          end
          next
        end
        elem_links = elem.css("a")
        date = pick_date(elem.at_css('.popup_date'))
        new_favorites << {
            favorite_notification_id: elem.at_css("input")["value"],
            name: elem_links[0].content,
            profile: fa_url(elem_links[0]['href']),
            profile_name: last_path(elem_links[0]['href']),
            submission_id: last_path(elem_links[1]['href']),
            submission_name: elem_links[1].content,
            posted: date,
            posted_at: to_iso8601(date)
        }
      end
    end
    # Parse new journal notifications
    new_journals = []
    journals_elem = html.at_css("ul#journals")
    if journals_elem
      journals_elem.css("li:not(.section-controls)").each do |elem|
        # Deleted journals are only displayed when the poster's page has been deactivated
        if elem.at_css("input")['checked'] == "checked"
          if include_deleted
            new_journals << {
                favorite_notification_id: "",
                name: "This journal has been removed by the poster",
                profile: "",
                profile_name: "",
                submission_id: "",
                submission_name: "This journal has been removed by the poster",
                posted: "",
                posted_at: ""
            }
          end
          next
        end
        elem_links = elem.css("a")
        date = pick_date(elem.at_css('.popup_date'))
        new_journals << {
            journal_id: elem.at_css("input")['value'],
            title: elem_links[0].content,
            name: elem_links[1].content,
            profile: fa_url(elem_links[1]['href']),
            profile_name: last_path(elem_links[1]['href']),
            posted: date,
            posted_at: to_iso8601(date)
        }
      end
    end
    # Create response
    {
        current_user: login_user,
        notification_counts: {
            submissions: num_submissions,
            comments: num_comments,
            journals: num_journals,
            favorites:  num_favorites,
            watchers:  num_watchers,
            notes: num_notes,
            trouble_tickets: num_trouble_tickets
        },
        new_watches: new_watches,
        new_submission_comments: new_submission_comments,
        new_journal_comments: new_journal_comments,
        new_shouts: new_shouts,
        new_favorites: new_favorites,
        new_journals: new_journals
    }
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

  def fetch_url(path)
    path = strip_leading_slash(path)
    "#{fa_fetch_address}/#{path}"
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

  def escape(name)
    CGI::escape(name)
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

  def get_current_user(html, url)
    name_elem = html.at_css("a#my-username")
    if name_elem.nil?
      raise FALoginError.new(url)
    end
    {
        "name": name_elem.content.strip.gsub(/^~/, ''),
        "profile": fa_url(name_elem['href'][1..-1]),
        "profile_name": last_path(name_elem['href'])
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
