# faexport.rb - Simple data export and feeds from FA
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

$:<< File.dirname(__FILE__)

require 'active_support'
require 'active_support/core_ext'
require 'builder'
require 'faexport/scraper'
require 'redcarpet'
require 'sinatra/base'
require 'sinatra/json'
require 'yaml'
require 'tilt'

Tilt.register Tilt::RedcarpetTemplate, 'markdown', 'md'

module FAExport
  class << self
    attr_accessor :config
  end

  class Application < Sinatra::Base
    enable :logging
    set :public_folder, File.join(File.dirname(__FILE__), 'faexport', 'public')
    set :views, File.join(File.dirname(__FILE__), 'faexport', 'views')
    set :markdown, with_toc_data: true, fenced_code_blocks: true

    USER_REGEX = /((?:[a-zA-Z0-9\-_~.]|%5B|%5D|%60)+)/
    ID_REGEX = /([0-9]+)/
    COOKIE_REGEX = /^b=[a-z0-9\-]+; a=[a-z0-9\-]+$/

    def initialize(app, config = {})
      FAExport.config = config.with_indifferent_access
      FAExport.config[:cache_time] ||= 30 # 30 seconds
      FAExport.config[:cache_time_long] ||= 86400 # 1 day
      FAExport.config[:redis_url] ||= (ENV['REDIS_URL'] || ENV['REDISTOGO_URL'])
      FAExport.config[:username] ||= ENV['FA_USERNAME']
      FAExport.config[:password] ||= ENV['FA_PASSWORD']
      FAExport.config[:cookie] ||= ENV['FA_COOKIE']
      FAExport.config[:rss_limit] ||= 10
      FAExport.config[:content_types] ||= {
        'json' => 'application/json',
        'xml' => 'application/xml',
        'rss' => 'application/rss+xml'
      }

      @cache = RedisCache.new(FAExport.config[:redis_url],
                              FAExport.config[:cache_time],
                              FAExport.config[:cache_time_long])
      @fa = Furaffinity.new(@cache)

      @system_cookie = FAExport.config[:cookie] || @cache.redis.get('login_cookie') 
      unless @system_cookie
        @system_cookie = @fa.login(FAExport.config[:username], FAExport.config[:password])
        @cache.redis.set('login_cookie', @system_cookie)
      end

      super(app)
    end

    helpers do
      def cache(key)
        # Cache rss feeds for one hour
        long_cache = key =~ /\.rss$/
        @cache.add("#{key}.#{@fa.safe_for_work}", long_cache) { yield }
      end

      def set_content_type(type)
        content_type FAExport.config[:content_types][type], 'charset' => 'utf-8'
      end

      def ensure_login!
        unless @user_cookie
          raise FALoginCookieError,
            "You must provide a valid login cookie in the header 'FA_COOKIE'"
        end
      end
    end

    before do
      @user_cookie = request.env['HTTP_FA_COOKIE']
      if @user_cookie
        if @user_cookie =~ COOKIE_REGEX
          @fa.login_cookie = @user_cookie.strip
        else
          raise FALoginCookieError,
            "The login cookie provided must be in the format "\
            "'b=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx; a=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'"
        end
      else
        @fa.login_cookie = @system_cookie
      end

      @fa.safe_for_work = !!params[:sfw]
    end

    after do
      @fa.login_cookie = nil
      @fa.safe_for_work = false
    end

    get '/' do
      haml :index, layout: :page
    end

    get '/docs' do
      haml :page do
        markdown :docs
      end
    end

    get %r{/home\.(json|xml)} do |type|
      set_content_type(type)
      cache("home:#{type}") do
        case type
        when 'json'
          JSON.pretty_generate @fa.home
        when 'xml'
          @fa.home.to_xml(root: 'home', skip_types: true)
        end
      end
    end

    # GET /user/{name}.json
    # GET /user/{name}.xml
    get %r{/user/#{USER_REGEX}\.(json|xml)} do |name, type|
      set_content_type(type)
      cache("data:#{name}.#{type}") do
        case type
        when 'json'
          JSON.pretty_generate @fa.user(name)
        when 'xml'
          @fa.user(name).to_xml(root: 'user', skip_types: true)
        end
      end
    end

    # GET /user/{name}/shouts.rss
    # GET /user/{name}/shouts.json
    # GET /user/{name}/shouts.xml
    get %r{/user/#{USER_REGEX}/shouts\.(rss|json|xml)} do |name, type|
      set_content_type(type)
      cache("shouts:#{name}.#{type}") do
        case type
        when 'rss'
          @name = name.capitalize
          @resource = 'shouts'
          @link = @fa.fa_url("user/#{name}")
          @posts = @fa.shouts(name).map do |shout|
            @post = {
              title: "Shout from #{shout[:name]}",
              link: @fa.fa_url("user/#{name}/##{shout[:id]}"),
              posted: shout[:posted]
            }
            @description = shout[:text]
            builder :post
          end
          builder :feed
        when 'json'
          JSON.pretty_generate @fa.shouts(name)
        when 'xml'
          @fa.shouts(name).to_xml(root: 'shouts', skip_types: true)
        end
      end
    end

    # GET /user/{name}/watching.json
    # GET /user/{name}/watching.xml
    # GET /user/{name}/watchers.json
    # GET /user/{name}/watchers.xml
    get %r{/user/#{USER_REGEX}/(watching|watchers)\.(json|xml)} do |name, mode, type|
      set_content_type(type)
      page = params[:page] =~ /^[0-9]+$/ ? params[:page] : 1
      is_watchers = mode == 'watchers'
      cache("watching:#{name}.#{type}.#{mode}.#{page}") do
        case type
        when 'json'
          JSON.pretty_generate @fa.budlist(name, page, is_watchers)
        when 'xml'
          @fa.budlist(name, page, is_watchers).to_xml(root: 'users', skip_types: true)
        end
      end
    end

    # GET /user/{name}/commissions.json
    # GET /user/{name}/commissions.xml
    get %r{/user/#{USER_REGEX}/commissions\.(json|xml)} do |name, type|
      set_content_type(type)
      cache("commissions:#{name}.#{type}") do
        case type
        when 'json'
          JSON.pretty_generate @fa.commissions(name)
        when 'xml'
          @fa.commissions(name).to_xml(root: 'commissions', skip_types: true)
        end
      end
    end

    # GET /user/{name}/journals.rss
    # GET /user/{name}/journals.json
    # GET /user/{name}/journals.xml
    get %r{/user/#{USER_REGEX}/journals\.(rss|json|xml)} do |name, type|
      set_content_type(type)
      page = params[:page] =~ /^[0-9]+$/ ? params[:page] : 1
      full = !!params[:full]
      cache("journals:#{name}.#{type}.#{page}.#{full}") do
        case type
        when 'rss'
          @name = name.capitalize
          @resource = 'journals'
          @link = @fa.fa_url("journals/#{name}/")
          @posts = @fa.journals(name, 1).take(FAExport.config[:rss_limit]).map do |journal|
            cache "journal:#{journal[:id]}.rss" do
              @post = @fa.journal(journal[:id])
              @description = "<p>#{@post[:description]}</p>"
              builder :post
            end
          end
          builder :feed
        when 'json'
          journals = @fa.journals(name, page)
          journals = journals.map{|j| j[:id]} unless full
          JSON.pretty_generate journals
        when 'xml'
          journals = @fa.journals(name, page)
          journals = journals.map{|j| j[:id]} unless full
          journals.to_xml(root: 'journals', skip_types: true)
        end
      end
    end

    # GET /user/{name}/gallery.rss
    # GET /user/{name}/gallery.json
    # GET /user/{name}/gallery.xml
    # GET /user/{name}/scraps.rss
    # GET /user/{name}/scraps.json
    # GET /user/{name}/scraps.xml
    # GET /user/{name}/favorites.rss
    # GET /user/{name}/favorites.json
    # GET /user/{name}/favorites.xml
    get %r{/user/#{USER_REGEX}/(gallery|scraps|favorites)\.(rss|json|xml)} do |name, folder, type|
      set_content_type(type)

      offset = {}
      offset[:page] = params[:page] if params[:page] =~ /^[0-9]+$/
      offset[:prev] = params[:prev] if params[:prev] =~ ID_REGEX
      offset[:next] = params[:next] if params[:next] =~ ID_REGEX

      full = !!params[:full]
      include_deleted = !!params[:include_deleted]

      cache("#{folder}:#{name}.#{type}.#{offset}.#{full}.#{include_deleted}") do
        case type
        when 'rss'
          @name = name.capitalize
          @resource = folder.capitalize
          @link = @fa.fa_url("#{folder}/#{name}/")
          subs = @fa.submissions(name, folder, {})
          subs = subs.reject{|sub| sub[:id].blank?} unless include_deleted
          @posts = subs.take(FAExport.config[:rss_limit]).map do |sub|
            cache "submission:#{sub[:id]}.rss" do
              @post = @fa.submission(sub[:id])
              @description = "<a href=\"#{@post[:link]}\"><img src=\"#{@post[:thumbnail]}"\
                             "\"/></a><br/><br/><p>#{@post[:description]}</p>"
              builder :post
            end
          end
          builder :feed
        when 'json'
          subs =  @fa.submissions(name, folder, offset)
          subs = subs.reject{|sub| sub[:id].blank?} unless include_deleted
          subs = subs.map{|sub| sub[:id]} unless full
          JSON.pretty_generate subs
        when 'xml'
          subs =  @fa.submissions(name, folder, offset)
          subs = subs.reject{|sub| sub[:id].blank?} unless include_deleted
          subs = subs.map{|sub| sub[:id]} unless full
          subs.to_xml(root: 'submissions', skip_types: true)
        end
      end
    end

    # GET /submission/{id}.json
    # GET /submission/{id}.xml
    get %r{/submission/#{ID_REGEX}\.(json|xml)} do |id, type|
      set_content_type(type)
      cache("submission:#{id}.#{type}") do
        case type
        when 'json'
          JSON.pretty_generate @fa.submission(id)
        when 'xml'
          @fa.submission(id).to_xml(root: 'submission', skip_types: true)
        end
      end
    end

    # GET /journal/{id}.json
    # GET /journal/{id}.xml
    get %r{/journal/#{ID_REGEX}\.(json|xml)} do |id, type|
      set_content_type(type)
      cache("journal:#{id}.#{type}") do
        case type
        when 'json'
          JSON.pretty_generate @fa.journal(id)
        when 'xml'
          @fa.journal(id).to_xml(root: 'journal', skip_types: true)
        end
      end
    end

    # GET /submission/{id}/comments.json
    # GET /submission/{id}/comments.xml
    get %r{/submission/#{ID_REGEX}/comments\.(json|xml)} do |id, type|
      set_content_type(type)
      include_hidden = !!params[:include_hidden]
      cache("submissions_comments:#{id}.#{type}.#{include_hidden}") do
        case type
        when 'json'
          JSON.pretty_generate @fa.submission_comments(id, include_hidden)
        when 'xml'
          @fa.submission_comments(id, include_hidden).to_xml(root: 'comments', skip_types: true)
        end
      end
    end

    # GET /journal/{id}/comments.json
    # GET /journal/{id}/comments.xml
    get %r{/journal/#{ID_REGEX}/comments\.(json|xml)} do |id, type|
      set_content_type(type)
      include_hidden = !!params[:include_hidden]
      cache("journal_comments:#{id}.#{type}.#{include_hidden}") do
        case type
        when 'json'
          JSON.pretty_generate @fa.journal_comments(id, include_hidden)
        when 'xml'
          @fa.journal_comments(id, include_hidden).to_xml(root: 'comments', skip_types: true)
        end
      end
    end

    # GET /search.json?q={query}
    # GET /search.xml?q={query}
    # GET /search.rss?q={query}
    get %r{/search\.(json|xml|rss)} do |type|
      set_content_type(type)
      full = !!params[:full]
      cache("search_results:#{params.to_s}.#{type}") do
        case type
        when 'json'
          results, _ = @fa.search(params)
          results = results.map{|result| result[:id]} unless full
          JSON.pretty_generate results
        when 'xml'
          results, _ = @fa.search(params)
          results = results.map{|result| result[:id]} unless full
          results.to_xml(root: 'results', skip_types: true)
        when 'rss'
          results, uri = @fa.search(params)

          @name = params['q']
          @info = "Search for '#{params['q']}'"
          @link = uri.to_s
          @posts = results.take(FAExport.config[:rss_limit]).map do |sub|
            cache "submission:#{sub[:id]}.rss" do
              @post = @fa.submission(sub[:id])
              @description = "<a href=\"#{@post[:link]}\"><img src=\"#{@post[:thumbnail]}"\
                             "\"/></a><br/><br/><p>#{@post[:description]}</p>"
              builder :post
            end
          end
          builder :feed
        end
      end
    end

    # GET /new_submissions.json
    get %r{/new_submissions\.(json|xml|rss)} do |type|
      ensure_login!
      set_content_type(type)
      from_id = params['from']
      cache("submissions:#{@user_cookie}:#{from_id}.#{type}") do
        case type
        when 'json'
          JSON.pretty_generate @fa.new_submissions(from_id)
        when 'xml'
          @fa.new_submissions(from_id).to_xml(root: 'results', skip_types: true)
        when 'rss'
          results = @fa.new_submissions(from_id)

          @name = "New submissions"
          @info = "New submissions for #{results["current_user"]["name"]}"
          @link = "https://www.furaffinity.net/msg/submissions/"
          @posts = results["new_submissions"].take(FAExport.config[:rss_limit]).map do |sub|
            cache "submission:#{sub[:id]}.rss" do
              @post = @fa.submission(sub[:id])
              @description = "<a href=\"#{@post[:link]}\"><img src=\"#{@post[:thumbnail]}"\
                             "\"/></a><br/><br/><p>#{@post[:description]}</p>"
              builder :post
            end
          end
          builder :feed
        end
      end
    end

    # GET /notifications.json
    get %r{/notifications\.(json|xml)} do |type|
      ensure_login!
      # # TODO: write docs
      include_deleted = !!params[:include_deleted]
      set_content_type(type)
      cache("notifications:#{@user_cookie}:#{include_deleted}.#{type}") do
        case type
        when 'json'
          JSON.pretty_generate @fa.notifications(include_deleted)
        when 'xml'
          @fa.notifications(include_deleted).to_xml(root: 'results', skip_types: true)
        end
      end
    end

    # GET /notifications/watches.rss
    get %r{/notifications/watches\.(rss)} do |type|
      ensure_login!
      include_deleted = !!params[:include_deleted]
      set_content_type(type)
      cache("notifications/watches:#{@user_cookie}:#{include_deleted}.#{type}") do
        case type
        when 'rss'
          results = @fa.notifications(include_deleted)
          watches = results[:watches]
          @name = "New watch notifications"
          @info = "New watch notifications for #{results[:current_user][:name]}. #{include_deleted ? "Including" : "Not including"} removed watches."
          @link = "https://www.furaffinity.net/msg/others/#watches"
          @posts = watches.map do |watch|
            @post = {
                title: "New watch by #{watch[:name]}",
                link: watch[:profile],
                posted: watch[:posted]
            }
            @description = "You have been watched by a new user <a href=\"#{watch[:profile]}\">#{watch[:name]}</a> <img src=\"#{watch[:avatar]}\" alt=\"avatar\"/>"
            builder :post
          end
          builder :feed
        end
      end
    end

    # GET /notifications/submission_comments.rss
    get %r{/notifications/submission_comments\.(rss)} do |type|
      ensure_login!
      include_deleted = !!params[:include_deleted]
      set_content_type(type)
      cache("notifications/submission_comments:#{@user_cookie}:#{include_deleted}.#{type}") do
        case type
        when 'rss'
          results = @fa.notifications(include_deleted)
          submission_comments = results[:new_submission_comments]
          @name = "New submission comment notifications"
          @info = "New submission comment notifications for #{results[:current_user][:name]}. #{include_deleted ? "Including" : "Not including"} removed comments/submissions."
          @link = "https://www.furaffinity.net/msg/others/#comments"
          @posts = submission_comments.map do |comment|
            @post = {
                title: "New submission comment by #{comment[:name]}",
                link: comment[:profile],
                posted: comment[:posted]
            }
            @description = "You have a new submission comment notification.
<a href=\"#{comment[:profile]}\">#{comment[:name]}</a> has made a new comment #{comment[:is_reply] ? "in response to your comment " : ""}on
#{comment[:your_submission] ? "your" : "their"} submission <a href=\"https://furaffinity.net/view/#{comment[:submission_id]}/\">#{comment[:title]}</a>"
            builder :post
          end
          builder :feed
        end
      end
    end

    post %r{/journal(\.json|)} do |type|
      ensure_login!
      journal = case type
                when '.json' then JSON.parse(request.body.read)
                else params
                end
      result = @fa.submit_journal(journal['title'], journal['description'])

      set_content_type('json')
      JSON.pretty_generate(result)
    end

    error FAError do
      err = env['sinatra.error']
      status case err
      when FASearchError      then 400
      when FALoginCookieError then 400
      when FAFormError        then 400
      when FAOffsetError      then 400
      when FALoginError       then @user_cookie ? 401 : 503
      when FASystemError      then 404
      when FAStatusError      then 502
      else 500
      end

      JSON.pretty_generate error: err.message, url: err.url
    end

    error do
      status 500
      'FAExport encounter an internal error'
    end
  end
end
