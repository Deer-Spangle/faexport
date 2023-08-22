# frozen_string_literal: true

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

require "net/http"
require "nokogiri"
require "open-uri"
require "prometheus/client"
require "redis"

USER_AGENT = "FAExport"
SEARCH_OPTIONS = {
  "perpage" => %w[24 48 72],
  "order_by" => %w[relevancy date popularity],
  "order_direction" => %w[asc desc],
  "range" => %w[24hours day 1day 72hours 3days 7days 30days month 90days 1year 3years 5years all],
  "mode" => %w[all any extended],
  "rating" => %w[general mature adult],
  "type" => %w[art flash photo music story poetry]
}
SEARCH_DEFAULTS = {
  "q" => "",
  "page" => 1,
  "perpage" => 72,
  "order_by" => "date",
  "order_direction" => "desc",
  "range" => "all",
  "mode" => "extended",
  "rating" => SEARCH_OPTIONS["rating"].join(","),
  "type" => SEARCH_OPTIONS["type"].join(",")
}
SEARCH_MULTIPLE = %w[rating type]
SEARCH_OLD_RANGE = {
  "day" => "1day",
  "24hours" => "1day",
  "72hours" => "3days",
  "week" => "7days",
  "month" => "30days"
}
PAGE_TYPES = {
  "view" => "fa/view",
  "user" => "fa/user",
  "" => "fa/home",
  "journal" => "fa/journal",
  "journals" => "fa/journals",
  "msg" => "fa/private",
  "watchlist" => "fa/watchlist",
  "fav" => "fa/mark_favorite",
  "unfav" => "fa/mark_favorite",
  "gallery" => "fa/gallery",
  "scraps" => "fa/scraps",
  "favorites" => "fa/favorites",
  "controls" => "fa/controls",
}
PAGE_OTHER = "other"
prom = Prometheus::Client.registry
$page_fetch_calls = prom.counter(
  :faexport_scraper_fetch_call_count,
  docstring: "Total number of calls which were made to the fetch method",
  labels: [:page_type]
)
$page_request_time = prom.histogram(
  :faexport_scraper_request_time_seconds,
  docstring: "How long the scraper took to scrape the specified page on FA, in seconds",
  labels: [:page_type]
)
$http_errors = prom.counter(
  :faexport_scraper_http_error_total,
  docstring: "Total number of http errors raised while making requests to FA",
  labels: [:page_type]
)
$cloudflare_errors = prom.counter(
  :faexport_scraper_cloudflare_error_total,
  docstring: "Total number of cloudflare errors returned by FA",
  labels: [:page_type]
)
(PAGE_TYPES.values + [PAGE_OTHER]).each do |page_type|
  $page_fetch_calls.init_label_set(page_type: page_type)
  $page_request_time.init_label_set(page_type: page_type)
  $http_errors.init_label_set(page_type: page_type)
  $cloudflare_errors.init_label_set(page_type: page_type)
end
$fa_users_online = prom.gauge(
  :faexport_fa_users_online_total,
  docstring: "Total number of users online, as reported by FA",
  labels: [:user_type]
)
%w[total guests registered other].each do |user_type|
  $fa_users_online.init_label_set(user_type: user_type)
end

class FAError < StandardError
  attr_accessor :url

  def initialize(url)
    super("Error accessing FA")
    @url = url
  end

  def error_type
    "fa_unknown"
  end

  def status_code
    500
  end
end

class FAFormError < FAError
  def initialize(url, field = nil)
    super(url)
    @field = field
  end

  def error_type
    "fa_form"
  end

  def status_code
    400
  end

  def to_s
    if @field
      "You must provide a value for the field '#{@field}'."
    else
      "There was an unknown error submitting to FA."
    end
  end
end

class FAOffsetError < FAError
  def initialize(url, message)
    super(url)
    @message = message
  end

  def error_type
    "fa_offset"
  end

  def status_code
    400
  end

  def to_s
    @message
  end
end

class FASearchError < FAError
  def initialize(key, value, url)
    super(url)
    @key = key
    @value = value
  end

  def error_type
    "fa_search"
  end

  def status_code
    400
  end

  def to_s
    field = @key.to_s
    multiple = SEARCH_MULTIPLE.include?(@key) ? "zero or more" : "one"
    options = SEARCH_OPTIONS[@key].join(", ")
    "The search field #{field} must contain #{multiple} of: #{options}.  You provided: #{@value}"
  end
end

class FAStatusError < FAError
  def initialize(url, status)
    super(url)
    @status = status
  end

  def error_type
    "fa_status"
  end

  def status_code
    502
  end

  def to_s
    "FA returned a status of '#{@status}' while trying to access #{@url}."
  end
end

class FASystemError < FAError
  def error_type
    "fa_system"
  end

  def status_code
    500
  end

  def to_s
    "FA returned an unknown system error page when trying to access #{@url}."
  end
end

class FANoTitleError < FASystemError
  def error_type
    "fa_no_title"
  end

  def status_code
    500
  end

  def to_s(*args)
    "FA returned a page without a title when trying to access #{@url}. This should not happen"
  end
end

class FAStyleError < FAError
  def error_type
    "fa_style"
  end

  def status_code
    400
  end

  def to_s
    "FA is not currently set to classic theme. Unfortunately this API currently only works if the authenticated
account is using classic theme. Please change your style to classic and try again."
  end
end

class FALoginError < FAError
  def error_type
    "fa_login"
  end

  def status_code
    401
  end

  def to_s
    "Unable to log into FA to access #{@url}."
  end
end

class FAGuestAccessError < FALoginError
  def error_type
    "fa_guest_access"
  end

  def status_code
    403
  end

  def to_s(*args)
    "This page is not available to guests"
  end
end

class FALoginCookieError < FAError
  def initialize(message)
    super(nil)
    @message = message
  end

  def error_type
    "fa_login_cookie"
  end

  def status_code
    401
  end

  def to_s
    @message
  end
end

class FANotFoundError < FAError
  def error_type
    "fa_not_found"
  end

  def status_code
    404
  end

  def to_s
    "Submission or journal could not be found on #{@url}."
  end
end

class FAContentFilterError < FAError
  def error_type
    "fa_content_filter"
  end

  def status_code
    403
  end

  def to_s
    "Submission cannot be accessed due to content filter settings"
  end
end

class FANoUserError < FAError
  def error_type
    "fa_no_user"
  end

  def status_code
    404
  end

  def to_s
    "User could not be found on #{@url}"
  end
end

class FAAccountDisabledError < FAError
  def error_type
    "fa_account_disabled"
  end

  def status_code
    404
  end

  def to_s
    "User has disabled their account on #{url}"
  end
end

class FACloudflareError < FAError
  def error_type
    "fa_cloudflare"
  end

  def status_code
    503
  end

  def to_s
    "Cannot access FA, #{@url} as cloudflare protection is up"
  end
end


class FASlowdownError < FACloudflareError

  def error_type
    "fa_slowdown"
  end

  def status_code
    429
  end

  def to_s
    "FurAffinity has returned an error page asking to slow down the request rate from this FAExport instance."
  end
end


class CacheError < FAError
  def initialize(message)
    super(nil)
    @message = message
  end

  def error_type
    "cache_error"
  end

  def status_code
    500
  end

  def to_s
    @message
  end
end

class RedisCache
  attr_accessor :redis

  def initialize(redis_url = nil, expire = 0, long_expire = 0)
    @redis = redis_url ? Redis.new(url: redis_url) : Redis.new
    @expire = expire
    @long_expire = long_expire
  end

  def add(key, wait_long = false)
    @redis.get(key) || begin
      value = yield
      @redis.set(key, value)
      @redis.expire(key, wait_long ? @long_expire : @expire)
      value
    end
  rescue Redis::BaseError => e
    if e.message.include? "OOM"
      raise CacheError.new(
        "The page returned from FA was too large to fit in the cache"
      )
    end

    raise CacheError.new("Error accessing Redis Cache: #{e.message}")
  end

  def save_status(status)
    @redis.set("#status", status)
    @redis.expire("#status", @expire)
  end

  def remove(key)
    @redis.del(key)
  end
end

class Furaffinity
  attr_accessor :login_cookie, :safe_for_work

  def initialize(cache)
    @cache = cache
    @safe_for_work = false
  end

  def home
    html = fetch("")
    groups = html.css("#frontpage > .old-table-emulation")
    data = groups.map do |group|
      group.css("figure").map { |art| build_submission(art) }
    end
    {
      artwork: data[0],
      writing: data[1],
      music: data[2],
      crafts: data[3]
    }
  end

  def browse(params)
    page = params["page"] =~ /^[0-9]+$/ ? params["page"] : "1"
    perpage = SEARCH_OPTIONS["perpage"].include?(params["perpage"]) ? params["perpage"] : SEARCH_DEFAULTS["perpage"]
    ratings =
      if params.key?("rating") && params["rating"].gsub(" ", "").split(",").all? { |v| SEARCH_OPTIONS["rating"].include? v }
        params["rating"].gsub(" ", "").split(",")
      else
        SEARCH_DEFAULTS["rating"].split(",")
      end

    options = {
      perpage: perpage,
      rating_general: ratings.include?("general") ? 1 : 0,
      rating_mature: ratings.include?("mature") ? 1 : 0,
      rating_adult: ratings.include?("adult") ? 1 : 0
    }

    raw = @cache.add("url:browse:#{params}") do
      response = post("/browse/#{page}/", options)
      raise FAStatusError.new(fa_url("/browse/#{page}/"), response.message) unless response.is_a?(Net::HTTPSuccess)

      response.body
    end

    # Parse browse results
    html = Nokogiri::HTML(raw)
    gallery = html.css("section#gallery-browse")

    gallery.css("figure").map { |art| build_submission(art) }
  end

  def status
    json = @cache.add("#status", false) do
      parse_status fetch("")
    end
    JSON.parse json
  end

  def user(name)
    profile = "user/#{escape(name)}/"
    html = fetch(profile)
    info = html.css(".ldot")[0].children.to_s
    stats = html.css(".ldot")[1].children.to_s
    date = html_field(info, "Registered Since")
    user_title = html_field(info, "User Title")
    tables = {}
    html.css("table.maintable").each do |table|
      title = table.at_css("td.cat b")
      tables[title.content.strip] = table if title
    end
    guest_access = begin
                     fetch(profile, as_guest: true)
                     true
                   rescue => e
                     e.class != FAGuestAccessError
                   end

    {
      id: nil,
      name: html.at_css(".addpad.lead b").content.strip[1..-1],
      profile: fa_url(profile),
      account_type: html.at_css(".addpad.lead").content[/\((.+?)\)/, 1].strip,
      avatar: "https:#{html.at_css("td.addpad img")["src"]}",
      full_name: html.at_css("title").content[/Userpage of(.+?)--/, 1].strip,
      artist_type: user_title, # Backwards compatibility
      user_title: user_title,
      registered_since: date,
      registered_at: to_iso8601(date),
      guest_access: guest_access,
      current_mood: html_field(info, "Current Mood"),
      artist_profile: html_long_field(info, "Artist Profile"),
      pageviews: html_field(stats, "Page Visits"),
      submissions: html_field(stats, "Submissions"),
      comments_received: html_field(stats, "Comments Received"),
      comments_given: html_field(stats, "Comments Given"),
      journals: html_field(stats, "Journals"),
      favorites: html_field(stats, "Favorites"),
      featured_submission: build_submission(html.at_css(".userpage-featured-submission b")),
      profile_id: build_submission(html.at_css("#profilepic-submission b")),
      artist_information: select_artist_info(tables["Artist Information"]),
      contact_information: select_contact_info(tables["Contact Information"]),
      watchers: select_watchers_info(tables["Watched By"], "watched-by"),
      watching: select_watchers_info(tables["Is Watching"], "is-watching")
    }
  end

  def budlist(name, page, is_watchers)
    mode = is_watchers ? "to" : "by"
    url = "watchlist/#{mode}/#{escape(name)}/#{page}/"
    html = fetch(url)

    html.css(".artist_name").map(&:content)
  end

  def submission(id, is_login = false)
    url = "view/#{id}/"
    html = fetch(url)

    parse_submission_page(id, html, is_login)
  end

  def favorite_submission(id, fav_status, fav_key)
    url = "#{fav_status ? "fav" : "unfav"}/#{id}/?key=#{fav_key}"
    raise FAFormError.new(fa_url(url), "fav_status") unless [true, false].include? fav_status
    raise FAFormError.new(fa_url(url), "fav_key") unless fav_key
    raise FALoginError.new(fa_url(url)) unless login_cookie

    html = fetch(url)
    parse_submission_page(id, html, true)
  end

  def journal(id)
    html = fetch("journal/#{id}/")
    date = pick_date(html.at_css(".journal-title-box .popup_date"))
    profile_url = html.at_css("td.cat .journal-title-box a")["href"][1..-1]
    journal_header =
      unless html.at_css(".journal-header").nil?
        html.at_css(".journal-header").children[0..-3].to_s.strip
      end
    journal_footer =
      unless html.at_css(".journal-footer").nil?
        html.at_css(".journal-footer").children[2..-1].to_s.strip
      end

    {
      title: html.at_css(".journal-title-box .no_overflow").content.gsub(/\A[[:space:]]+|[[:space:]]+\z/, ""),
      description: html.at_css("td.alt1 div.no_overflow").children.to_s.strip,
      journal_header: journal_header,
      journal_body: html.at_css(".journal-body").children.to_s.strip,
      journal_footer: journal_footer,
      name: html.at_css("td.cat .journal-title-box a").content,
      profile: fa_url(profile_url),
      profile_name: last_path(profile_url),
      avatar: "https:#{html.at_css("img.avatar")["src"]}",
      link: fa_url("journal/#{id}/"),
      posted: date,
      posted_at: to_iso8601(date)
    }
  end

  def submissions(user, folder, offset)
    if offset.size > 1
      raise FAOffsetError.new(
        fa_url("#{folder}/#{escape(user)}/"),
        'You may only provide one of "page", "next" or "prev" as a parameter'
      )
    elsif folder == "favorites" && offset[:page]
      raise FAOffsetError.new(
        fa_url("#{folder}/#{escape(user)}/"),
        "Due to a change by Furaffinity, favorites can no longer be accessed by page. See https://faexport.spangle.org.uk/docs#get-user-name-folder for more details."
      )
    elsif folder != "favorites" && (offset[:next] || offset[:prev])
      raise FAOffsetError.new(
        fa_url("#{folder}/#{escape(user)}/"),
        'The options "next" and "prev" are only usable on favorites. Use "page" instead with a page number'
      )
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

    html.css(".gallery > figure").map { |art| build_submission(art) }
  end

  def journals(user, page)
    html = fetch("journals/#{escape(user)}/#{page}")
    html.xpath('//table[starts-with(@id, "jid")]').map do |j|
      title = j.at_css(".cat a")
      contents = j.at_css(".alt1 table")
      info = contents.at_css(".ldot table")
      date = pick_date(info.at_css(".popup_date"))
      {
        id: j["id"].gsub("jid:", ""),
        title: title.content.gsub(/\A[[:space:]]+|[[:space:]]+\z/, ""),
        description: contents.at_css("div.no_overflow").children.to_s.strip,
        link: fa_url(title["href"][1..-1]),
        posted: date,
        posted_at: to_iso8601(date)
      }
    end
  end

  def shouts(user)
    html = fetch("user/#{escape(user)}/")
    html.xpath('//table[starts-with(@id, "shout")]').map do |shout|
      name = shout.at_css("td.lead.addpad a")
      date = pick_date(shout.at_css(".popup_date"))
      profile_url = name["href"][1..-1]
      {
        id: shout.attr("id"),
        name: name.content,
        profile: fa_url(profile_url),
        profile_name: last_path(profile_url),
        avatar: "https:#{shout.at_css("td.alt1.addpad img")["src"]}",
        posted: date,
        posted_at: to_iso8601(date),
        text: shout.css(".no_overflow.alt1")[0].children.to_s.strip
      }
    end
  end

  def commissions(user)
    html = fetch("commissions/#{escape(user)}")
    return [] if html.at_css("#no-images")

    html.css("table.types-table tr").map do |com|
      {
        title: com.at_css(".info dt").content.strip,
        price: com.at_css(".info dd span").next.content.strip,
        description: com.at_css(".desc").children.to_s.strip,
        submission: build_submission(com.at_css("b"))
      }
    end
  end

  def submission_comments(id, include_hidden)
    comments("view/#{id}/", include_hidden)
  end

  def journal_comments(id, include_hidden)
    comments("journal/#{id}/", include_hidden)
  end

  # Also returns the URI of the search
  def search(options = {})
    return [] if options["q"].blank?

    options = SEARCH_DEFAULTS.merge(options)
    params = {}

    # Handle page specification
    page = options["page"]
    if page !~ /[0-9]+/ || page.to_i <= 1
      options["page"] = 1
      params["do_search"] = "Search"
    else
      options["page"] = options["page"].to_i - 1
      params["next_page"] = ">>> #{options["perpage"]} more >>>"
    end

    # Construct params, to send in POST request
    options.each do |key, value|
      name = key.gsub("_", "-")
      # If this is the range, remap old values to new ones
      if name == "range"
        if SEARCH_OLD_RANGE.include? value
          value = SEARCH_OLD_RANGE[value]
        end
      end

      # Convert from API format, to FA format
      if SEARCH_MULTIPLE.include? key
        values = options[key].gsub(" ", "").split(",")
        unless values.all? { |v| SEARCH_OPTIONS[key].include? v }
          raise FASearchError.new(key, options[key], fa_url("search"))
        end

        values.each { |v| params["#{name}-#{v}"] = "on" }
      elsif SEARCH_OPTIONS.keys.include? key
        unless SEARCH_OPTIONS[key].include? options[key].to_s
          raise FASearchError.new(key, options[key], fa_url("search"))
        end

        params[name] = value
      elsif SEARCH_DEFAULTS.keys.include? key
        params[name] = value
      end
    end

    # Get search response
    raw = @cache.add("url:search:#{params}") do
      response = post("/search/", params)
      raise FAStatusError.new(fa_url("search/"), response.message) unless response.is_a?(Net::HTTPSuccess)

      response.body
    end
    # Parse search results
    html = Nokogiri::HTML(raw)
    # Get search results. Even a search with no matches gives this div.
    results = html.at_css("#search-results")
    # If form fails to submit, this div will not be there.
    raise FAFormError.new(fa_url("/search/")) if results.nil?

    html.css(".gallery > figure").map { |art| build_submission(art) }
  end

  def submit_journal(title, description)
    url = "controls/journal/"
    raise FAFormError.new(fa_url(url), "title") unless title
    raise FAFormError.new(fa_url(url), "description") unless description
    raise FALoginError.new(fa_url(url)) unless login_cookie

    html = fetch(url)
    key = html.at_css('form#MsgForm input[name="key"]')["value"]
    response = post(
      "/controls/journal/",
      {
        "id" => "",
        "key" => key,
        "do" => "update",
        "subject" => title,
        "message" => description
      }
    )
    raise FAFormError.new(fa_url("controls/journal/")) unless response.is_a?(Net::HTTPMovedTemporarily)

    {
      url: fa_url(response["location"][1..-1])
    }
  end

  def new_submissions(from_id)
    # Set pagination
    url = "msg/submissions/new#{"~#{from_id}@72/" if from_id}"

    # Get page code
    html = fetch(url)

    login_user = get_current_user(html, url)
    submissions = html.css(".gallery > figure").map { |art| build_submission_notification(art) }
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
    html.css("a.notification-container").each do |elem|
      count = Integer(elem["title"].gsub(",", "").split[0])
      if elem["title"].include? "Submission"
        num_submissions = count
      elsif elem["title"].include? "Comment"
        num_comments = count
      elsif elem["title"].include? "Journal"
        num_journals = count
      elsif elem["title"].include? "Favorite"
        num_favorites = count
      elsif elem["title"].include? "Watch"
        num_watchers = count
      elsif elem["title"].include? "Unread Notes"
        num_notes = count
      elsif elem["title"].include? "Troubleticket Replies"
        num_trouble_tickets = count
      end
    end
    # Parse new watcher notifications
    new_watches = []
    watches_elem = html.at_css("ul#watches")
    watches_elem&.css("li:not(.section-controls)")&.each do |elem|
      if elem.at_css("input")["checked"] == "checked"
        if include_deleted
          new_watches << {
            watch_id: "",
            name: "Removed by the user",
            profile: "",
            profile_name: "",
            avatar: fa_url(elem.at_css("img")["src"]),
            posted: "",
            posted_at: "",
            deleted: true
          }
        end
        next
      end
      date = pick_date(elem.at_css(".popup_date"))
      new_watches << {
        watch_id: elem.at_css("input")["value"],
        name: elem.at_css("span").content,
        profile: fa_url(elem.at_css("a")["href"]),
        profile_name: last_path(elem.at_css("a")["href"]),
        avatar: "https:#{elem.at_css("img")["src"]}",
        posted: date,
        posted_at: to_iso8601(date),
        deleted: false
      }
    end
    # Parse new submission comments notifications
    new_submission_comments = []
    submission_comments_elem = html.at_css("fieldset#messages-comments-submission")
    submission_comments_elem&.css("li:not(.section-controls)")&.each do |elem|
      if elem.at_css("input")["checked"] == "checked"
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
            posted_at: "",
            deleted: true
          }
        end
        next
      end
      elem_links = elem.css("a")
      date = pick_date(elem.at_css(".popup_date"))
      is_reply = elem.to_s.include?("<em>your</em> comment on")
      new_submission_comments << {
        comment_id: elem.at_css("input")["value"],
        name: elem_links[0].content,
        profile: fa_url(elem_links[0]["href"]),
        profile_name: last_path(elem_links[0]["href"]),
        is_reply: is_reply,
        your_submission: !is_reply || elem.css("em").length == 2 && elem.css("em").last.content == "your",
        their_submission: elem.css("em").last.content == "their",
        submission_id: elem_links[1]["href"].split("/")[-2],
        title: elem_links[1].content,
        posted: date,
        posted_at: to_iso8601(date),
        deleted: false
      }
    end
    # Parse new journal comments notifications
    new_journal_comments = []
    journal_comments_elem = html.at_css("fieldset#messages-comments-journal")
    journal_comments_elem&.css("li:not(.section-controls)")&.each do |elem|
      if elem.at_css("input")["checked"] == "checked"
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
            posted_at: "",
            deleted: true
          }
        end
        next
      end
      elem_links = elem.css("a")
      date = pick_date(elem.at_css(".popup_date"))
      is_reply = elem.to_s.include?("<em>your</em> comment on")
      new_journal_comments << {
        comment_id: elem.at_css("input")["value"],
        name: elem_links[0].content,
        profile: fa_url(elem_links[0]["href"]),
        profile_name: last_path(elem_links[0]["href"]),
        is_reply: is_reply,
        your_journal: !is_reply || elem.css("em").length == 2 && elem.css("em").last.content == "your",
        their_journal: elem.css("em").last.content == "their",
        journal_id: elem_links[1]["href"].split("/")[-2],
        title: elem_links[1].content,
        posted: date,
        posted_at: to_iso8601(date),
        deleted: false
      }
    end
    # Parse new shout notifications
    new_shouts = []
    shouts_elem = html.at_css("fieldset#messages-shouts")
    shouts_elem&.css("li:not(.section-controls)")&.each do |elem|
      if elem.at_css("input")["checked"] == "checked"
        if include_deleted
          new_shouts << {
            shout_id: "",
            name: "Shout has been removed from your page",
            profile: "",
            profile_name: "",
            posted: "",
            posted_at: "",
            deleted: true
          }
        end
        next
      end
      date = pick_date(elem.at_css(".popup_date"))
      new_shouts << {
        shout_id: elem.at_css("input")["value"],
        name: elem.at_css("a").content,
        profile: fa_url(elem.at_css("a")["href"]),
        profile_name: last_path(elem.at_css("a")["href"]),
        posted: date,
        posted_at: to_iso8601(date),
        deleted: false
      }
    end
    # Parse new favourite notifications
    new_favorites = []
    favorites_elem = html.at_css("ul#favorites")
    favorites_elem&.css("li:not(.section-controls)")&.each do |elem|
      if elem.at_css("input")["checked"] == "checked"
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
      date = pick_date(elem.at_css(".popup_date"))
      new_favorites << {
        favorite_notification_id: elem.at_css("input")["value"],
        name: elem_links[0].content,
        profile: fa_url(elem_links[0]["href"]),
        profile_name: last_path(elem_links[0]["href"]),
        submission_id: last_path(elem_links[1]["href"]),
        submission_name: elem_links[1].content,
        posted: date,
        posted_at: to_iso8601(date)
      }
    end
    # Parse new journal notifications
    new_journals = []
    journals_elem = html.at_css("ul#journals")
    journals_elem&.css("li:not(.section-controls)")&.each do |elem|
      # Deleted journals are only displayed when the poster's page has been deactivated
      if elem.at_css("input")["checked"] == "checked"
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
      date = pick_date(elem.at_css(".popup_date"))
      new_journals << {
        journal_id: elem.at_css("input")["value"],
        title: elem_links[0].content,
        name: elem_links[1].content,
        profile: fa_url(elem_links[1]["href"]),
        profile_name: last_path(elem_links[1]["href"]),
        posted: date,
        posted_at: to_iso8601(date)
      }
    end
    # Create response
    {
      current_user: login_user,
      notification_counts: {
        submissions: num_submissions,
        comments: num_comments,
        journals: num_journals,
        favorites: num_favorites,
        watchers: num_watchers,
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
    note_cookie = {
      inbox: "inbox",
      outbox: "sent",
      unread: "unread",
      archive: "archive",
      trash: "trash",
      high: "high_prio",
      medium: "medium_prio",
      low: "low_prio"
    }[folder.to_sym]
    html = fetch("msg/pms/", "folder=#{note_cookie}")
    notes_table = html.at_css("table#notes-list")
    notes_table.css("tr.note").map do |note|
      subject = note.at_css("td.subject")
      profile_from = note.at_css("td.col-from")
      profile_to = note.at_css("td.col-to")
      date = pick_date(note.at_css("span.popup_date"))
      if profile_to.nil?
        is_inbound = true
        profile = profile_from.at_css("a")
      elsif profile_from.nil?
        is_inbound = false
        profile = profile_to.at_css("a")
      else
        is_inbound = profile_to.content.strip == "me"
        profile = is_inbound ? profile_from.at_css("a") : profile_to.at_css("a")
      end
      name = profile&.content
      if profile.nil?
        profile_link = nil
        profile_name = nil
        user_deleted = true
      else
        profile_link = fa_url(profile["href"][1..-1])
        profile_name = last_path(profile["href"])
        user_deleted = false
      end
      {
        note_id: note.at_css("input")["value"].to_i,
        subject: subject.at_css("a.notelink").content,
        is_inbound: is_inbound,
        is_read: subject.at_css("a.notelink.note-unread").nil?,
        name: name,
        profile: profile_link,
        profile_name: profile_name,
        user_deleted: user_deleted,
        posted: date,
        posted_at: to_iso8601(date)
      }
    end
  end

  def note(id)
    url = "msg/pms/1/#{id}/"
    html = fetch(url)
    current_user = get_current_user(html, url)
    note_table = html.at_css(".note-view-container table.maintable table.maintable")
    raise FASystemError.new(url) if note_table.nil?

    note_header = note_table.at_css("td.head")
    note_from = note_header.css("em")[1].at_css("a")
    note_to = note_header.css("em")[2].at_css("a")
    is_inbound = current_user[:profile_name] == last_path(note_to["href"])
    profile = is_inbound ? note_from : note_to
    date = pick_date(note_table.at_css("span.popup_date"))
    description = note_table.at_css("td.text")
    desc_split = description.inner_html.split("—————————")
    name = profile&.content
    if profile.nil?
      profile_link = nil
      profile_name = nil
      avatar = nil
      user_deleted = true
    else
      profile_link = fa_url(profile["href"][1..-1])
      profile_name = last_path(profile["href"])
      avatar = "https#{note_table.at_css("img.avatar")["src"]}"
      user_deleted = false
    end
    {
      note_id: id,
      subject: note_header.at_css("em.title").content,
      is_inbound: is_inbound,
      name: name,
      profile: profile_link,
      profile_name: profile_name,
      user_deleted: user_deleted,
      posted: date,
      posted_at: to_iso8601(date),
      avatar: avatar,
      description: description.inner_html.strip,
      description_body: html_strip(desc_split.first.strip),
      preceding_notes: desc_split[1..-1].map do |note|
        note_html = Nokogiri::HTML(note)
        profile = note_html.at_css("a.linkusername")
        {
          name: profile.content.to_s,
          profile: fa_url("#{profile["href"][1..-1]}/"),
          profile_name: last_path(profile["href"]),
          description: note,
          description_body: html_strip(note.to_s.split("</a>:")[1..-1].join("</a>:"))
        }
      end
    }
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
    path = path[1..-1] while path.to_s.start_with? "/"
    path
  end

  private

  def fa_fetch_address
    if ENV["CF_BYPASS_SFW"] && @safe_for_work
      ENV["CF_BYPASS_SFW"]
    elsif ENV["CF_BYPASS"]
      ENV["CF_BYPASS"]
    else
      fa_address
    end
  end

  def fa_address
    "https://#{safe_for_work ? "sfw" : "www"}.furaffinity.net"
  end

  def html_strip(html_s)
    html_s.gsub(%r{^(<br ?/?>|\\r|\\n|\s)+}, "").gsub(%r{(<br ?/?>|\\r|\\n|\s)+$}, "")
  end

  def last_path(path)
    path.split("/").last
  end

  def field(info, field)
    # Most often, fields just show up in the format "Field: value"
    value = info.map { |i| i[/^#{field}: (.+)$/, 1] }.compact.first
    return value if value

    # However, they also can be "Field:" "value"
    info.each_with_index do |i, index|
      return info[index + 1] if i =~ /^#{field}:$/
    end
    nil
  end

  def pick_date(tag)
    tag.content.include?("ago") ? tag["title"] : tag.content
  end

  def to_iso8601(date)
    Time.parse("#{date} UTC").iso8601
  end

  def html_field(info, field)
    (info[%r{<b[^>]*>#{field}:</b>(.+?)<br>}, 1] || "").gsub(%r{</?[^>]+?>}, "").strip
  end

  def html_long_field(info, field)
    (info[%r{<b[^>]*>#{field}:</b><br>(.+)}m, 1] || "").strip
  end

  def select_artist_info(elem)
    elem = elem.at_css("td.alt1") if elem
    return nil unless elem

    info = {}
    elem.children.to_s.scan(%r{<strong>\s*(.*?)\s*</strong>\s*:\s*(.*?)\s*</div>}).each do |match|
      info[match[0]] = match[1]
    end
    info
  end

  def select_contact_info(elem)
    elem = elem.at_css("td.alt1") if elem
    return nil unless elem

    elem.css("div.classic-contact-info-item").map do |item|
      link_elem = item.at_css("a")
      {
        title: item.at_css("strong").content.gsub(/:\s*$/, ""),
        name: (link_elem || item.xpath("child::text()").to_s.squeeze(" ").strip),
        link: link_elem ? link_elem["href"] : ""
      }
    end
  end

  def select_watchers_info(elem, selector)
    users = elem.css("##{selector} a").map do |user|
      link = fa_url(user["href"][1..-1])
      {
        name: user.at_css(".artist_name").content.strip,
        profile_name: last_path(link),
        link: link
      }
    end
    {
      count: elem.at_css("td.cat a").content[/([0-9]+)/, 1].to_i,
      recent: users
    }
  end

  def escape(name)
    CGI.escape(name)
  end
  
  def full_cookie(extra_cookie: nil, as_guest: false)
    [
      (@login_cookie unless as_guest),
      extra_cookie
    ].compact().join(";")
  end

  def fetch(path, extra_cookie = nil, as_guest: false)
    split_path = strip_leading_slash(path).split("/", 2)
    page_type = PAGE_TYPES.fetch(split_path[0], PAGE_OTHER)
    $page_fetch_calls.increment(labels: {page_type: page_type})
    url = fetch_url(path)
    cookie_str = full_cookie(extra_cookie: extra_cookie, as_guest: as_guest)
    raw = @cache.add("url:#{url}:#{cookie_str}") do
      start = Time.now
      begin
        URI.parse(url).open({ "User-Agent" => USER_AGENT, "Cookie" => "#{cookie_str}" }) do |response|
          raise FAStatusError.new(url, response.status.join(" ")) if response.status[0] != "200"

          response.read
        end
      rescue OpenURI::HTTPError => e
        $http_errors.increment(labels: {page_type: page_type})
        # Detect and handle known errors
        if e.io.status[0] == "403" || e.io.status[0] == "503"
          raw = e.io.string
          html = Nokogiri::HTML(raw.encode("UTF-8", invalid: :replace, undef: :replace).delete("\000"))

          # Handle cloudflare errors
          if e.io.status[0] == "403" and html.at_css("#challenge-error-title")
            $cloudflare_errors.increment(labels: {page_type: page_type})
            raise FACloudflareError.new(url)
          end

          # Handle FA slowdown errors
          title = html.xpath("//head//title").first
          if e.io.status[0] == "503" and title.include?("Error 503") and raw.include?("you are requesting web pages too fast and are being rate limited")
            $slowdown_errors.increment(labels: {page_type: page_type})
            raise FASlowdownError.new(url)
          end
        end
        # Raise other HTTP errors as normal
        raise
      ensure
        request_time = Time.now - start
        $page_request_time.observe(request_time, labels: {page_type: page_type})
      end
    end

    html = Nokogiri::HTML(raw.encode("UTF-8", invalid: :replace, undef: :replace).delete("\000"))

    # Check for errors, and raise any that apply
    check_errors(html, url)

    # Parse and save the status, most pages have this, but watcher lists do not.
    parse_status(html)

    html
  end

  def check_errors(html, url)
    head = html.xpath("//head//title").first
    raise FANoTitleError.new(url) unless head

    # Check style is classic, but check login issues also
    stylesheet = html.at_css("head link[rel='stylesheet']")["href"]
    unless stylesheet.start_with?("/themes/classic/")

      # Check if it's a user page only visible to registered users
      system_message = html.at_css("#site-content section.notice-message")
      unless system_message.nil?
        message_header = system_message.at_css("h2").content
        message_content = system_message.at_css(".redirect-message").content
        if message_header == "System Message" && message_content.include?("has elected to make it available to registered users only.")
          raise FAGuestAccessError.new(url)
        end
      end

      # Check if the user is not logged in
      nav_bar = html.at_css("nav#ddmenu span.top-heading a")
      if nav_bar.to_s.include?('<a href="/login"><strong>Log In</strong></a>')
        raise FALoginError.new(url)
      end

      raise FAStyleError.new(url)
    end

    # Handle "Fatal system error" type errors
    if head.content == "System Error"
      error_msg = html.at_css("table.maintable td.alt1 font").content
      # Handle submission/journal not found errors
      if error_msg.include?("you are trying to find is not in our database.")
        raise FANotFoundError.new(url)
      end

      # Handle user profile not found, and user not found on journal listing
      if error_msg.include?("This user cannot be found") || error_msg.include?("User not found!")
        raise FANoUserError.new(url)
      end

      raise FASystemError.new(url)  # TODO: check if there is a test
    end

    # Handle "system message" type errors
    maintable_head = html.at_css("table.maintable td.cat b")
    if !maintable_head.nil? && maintable_head.content == "System Message"
      maintable_content = html.at_css("table.maintable td.alt1").content
      # Handle disabled accounts
      if maintable_content.include?("has voluntarily disabled access to their account and all of its contents.")
        raise FAAccountDisabledError.new(url)
      end

      # Handle user not existing (this version of the error is raised by watchers lists and galleries)
      if maintable_content.include?("Provided username not found in the database.") ||
          /The username "[^"]+" could not be found./.match?(maintable_content) ||
          /User "[^"]+" was not found in our database./.match?(maintable_content)
        raise FANoUserError.new(url)
      end

      # Handle content filter errors, accessing a nsfw submission with a sfw profile
      if maintable_content.include?("You are not allowed to view this image due to the content filter settings.")
        raise FAContentFilterError.new(url)
      end
    end
  end

  def post(path, params)
    uri = URI.parse(fa_fetch_address)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if fa_fetch_address.start_with?("https")
    request = Net::HTTP::Post.new(path)
    request.add_field("Content-Type", "application/x-www-form-urlencoded")
    request.add_field("Origin", fa_address)
    request.add_field("Referer", fa_address + path)
    request.add_field("Accept", "*/*")
    request.add_field("User-Agent", USER_AGENT)
    request.add_field("Cookie", @login_cookie)
    request.form_data = params
    http.request(request)
  end

  def build_submission(elem)
    if elem
      id = elem["id"]
      title =
        if elem.at_css("figcaption")
          elem.at_css("figcaption").at_css("p").at_css("a").content
        elsif elem.at_css("span")
          elem.at_css("span").content
        else
          ""
        end
      author_elem = elem.at_css("figcaption") ? elem.at_css("figcaption").css("p")[1].at_css("a") : nil
      sub = {
        id: id ? id.gsub(/sid[-_]/, "") : "",
        title: title,
        thumbnail: "https:#{elem.at_css("img")["src"]}",
        link: fa_url(elem.at_css("a")["href"][1..-1]),
        name: author_elem ? author_elem.content : "",
        profile: author_elem ? fa_url(author_elem["href"][1..-1]) : "",
        profile_name: author_elem ? last_path(author_elem["href"]) : ""
      }
      sub[:fav_id] = elem["data-fav-id"] if elem["data-fav-id"]
      sub
    end
  end

  def build_submission_notification(elem)
    title_link = elem.css("a")[1]
    uploader_link = elem.css("a")[2]
    {
      id: last_path(title_link["href"]),
      title: title_link.content.to_s,
      thumbnail: "https:#{elem.at_css("img")["src"]}",
      link: fa_url(title_link["href"][1..-1]),
      name: uploader_link.content.to_s,
      profile: fa_url(uploader_link["href"][1..-1]),
      profile_name: last_path(uploader_link["href"])
    }
  end

  def comments(path, include_hidden)
    html = fetch(path)
    comments = html.css("table.container-comment")
    reply_stack = []
    comments.map do |comment|
      has_timestamp = !!comment.attr("data-timestamp")
      id = comment.attr("id").gsub("cid:", "")
      width = comment.attr("width")[0..-2].to_i

      reply_stack.pop while reply_stack.any? && reply_stack.last[:width] <= width
      reply_to = reply_stack.any? ? reply_stack.last[:id] : ""
      reply_level = reply_stack.size
      reply_stack.push({ id: id, width: width })

      if has_timestamp
        date = pick_date(comment.at_css(".popup_date"))
        profile_url = comment.at_css("ul ul li a")["href"][1..-1]
        {
          id: id,
          name: comment.at_css(".replyto-name").content.strip,
          profile: fa_url(profile_url),
          profile_name: last_path(profile_url),
          avatar: "https:#{comment.at_css(".icon img")["src"]}",
          posted: date,
          posted_at: to_iso8601(date),
          text: comment.at_css(".message-text").children.to_s.strip,
          reply_to: reply_to,
          reply_level: reply_level,
          is_deleted: false
        }
      elsif include_hidden
        bold_text = comment.at_css("strong")
        comment_text = if bold_text
                         bold_text.content
                       else
                         comment.at_css(".block__deleted_content").content
                       end
        {
          id: id,
          text: comment_text,
          reply_to: reply_to,
          reply_level: reply_level,
          is_deleted: true
        }
      end
    end.compact
  end

  def get_current_user(html, url)
    name_elem = html.at_css("a#my-username")
    raise FALoginError.new(url) if name_elem.nil?

    {
      "name": name_elem.content.strip.gsub(/^~/, ""),
      "profile": fa_url(name_elem["href"][1..-1]),
      "profile_name": last_path(name_elem["href"])
    }
  end

  def parse_status(html)
    footer = html.css(".footer")
    center = footer.css("center")

    return if footer.empty?

    timestamp_line = footer[0].inner_html.split("\n").select { |line| line.strip.start_with? "Server Local Time: " }
    timestamp = timestamp_line[0].to_s.split("Time:")[1].strip

    counts = center.to_s.scan(/([0-9]+)\s*<b>/).map { |d| d[0].to_i }

    status = {
      online: {
        guests: counts[1],
        registered: counts[2],
        other: counts[3],
        total: counts[0]
      },
      fa_server_time: timestamp,
      fa_server_time_at: to_iso8601(timestamp)
    }
    status[:online].each do |key, value|
      $fa_users_online.set(value, labels: {user_type: key})
    end
    status_json = JSON.pretty_generate status
    @cache.save_status(status_json)
    status_json
  rescue StandardError
    # If we fail to read and save status, it's no big deal
  end

  def parse_submission_page(id, html, is_login)
    submission = html.css("div#page-submission table.maintable table.maintable")[-1]
    submission_title = submission.at_css(".classic-submission-title")
    raw_info = submission.at_css("td.alt1")
    info = raw_info.content.lines.map { |i| i.gsub(/^\p{Space}*/, "").rstrip }
    keywords = raw_info.css("div#keywords a")
    date = pick_date(raw_info.at_css(".popup_date"))
    img = html.at_css("img#submissionImg")
    actions_bar = html.css("#page-submission td.alt1 div.actions a")
    download_url = "https:#{actions_bar.select { |a| a.content == "Download" }.first["href"]}"
    profile_url = html.at_css("td.cat a")["href"][1..-1]
    og_thumb = html.at_css('meta[property="og:image"]')
    thumb_img = if og_thumb.nil? || og_thumb["content"].include?("/banners/fa_logo")
                  img ? "https:#{img["data-preview-src"]}" : nil
                else
                  og_thumb["content"].sub "http:", "https:"
                end

    submission = {
      title: submission_title.at_css("h2").content,
      description: submission.css("td.alt1")[2].children.to_s.strip,
      description_body: submission.css("td.alt1")[2].children.to_s.strip,
      name: html.css("td.cat a")[1].content,
      profile: fa_url(profile_url),
      profile_name: last_path(profile_url),
      avatar: "https:#{submission_title.at_css("img.avatar")["src"]}",
      link: fa_url("view/#{id}/"),
      posted: date,
      posted_at: to_iso8601(date),
      download: download_url,
      full: img ? "https:#{img["data-fullview-src"]}" : nil,
      thumbnail: thumb_img,
      category: field(info, "Category"),
      theme: field(info, "Theme"),
      species: field(info, "Species"),
      gender: field(info, "Gender"),
      favorites: field(info, "Favorites"),
      comments: field(info, "Comments"),
      views: field(info, "Views"),
      resolution: field(info, "Resolution"),
      rating: raw_info.at_css("div img")["alt"].gsub(" rating", ""),
      keywords: keywords ? keywords.map(&:content).reject(&:empty?) : []
    }

    if is_login
      fav_link = actions_bar.select { |a| a.content.end_with? "Favorites" }.first
      fav_status = fav_link.content.start_with?("-Remove")
      fav_key = fav_link["href"].split("?key=")[-1]

      submission[:fav_status] = fav_status
      submission[:fav_key] = fav_key
    end

    submission
  end
end
