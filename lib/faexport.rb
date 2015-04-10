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
require 'faexport/cache'
require 'faexport/scraper'
require 'rdiscount'
require 'sinatra/base'
require 'sinatra/json'
require 'yaml'

module FAExport
  class << self
    attr_accessor :config
  end

  class Application < Sinatra::Base
    set :public_folder, File.join(File.dirname(__FILE__), 'faexport', 'public')
    set :views, File.join(File.dirname(__FILE__), 'faexport', 'views')

    def initialize(app, config = {})
      FAExport.config = config.with_indifferent_access
      FAExport.config[:cache_time] ||= 30 # seconds
      FAExport.config[:redis_url] ||= ENV['REDISTOGO_URL']
      FAExport.config[:username] ||= ENV['FA_USERNAME']
      FAExport.config[:password] ||= ENV['FA_PASSWORD']
      FAExport.config[:rss_limit] ||= 10
      FAExport.config[:content_types] ||= {
        'json' => 'application/json',
        'xml' => 'application/xml',
        'rss' => 'application/rss+xml'
      }

      @cache = RedisCache.new(FAExport.config[:redis_url],
                              FAExport.config[:cache_time])
      @fa = Furaffinity.new(@cache)
      @fa.login(FAExport.config[:username], FAExport.config[:password])

      super(app)
    end

    helpers do
      def cache(key)
        @cache.add(key) { yield }
      end

      def set_content_type(type)
        content_type FAExport.config[:content_types][type]
      end
    end

    get '/' do
      @base_url = request.base_url
      haml :index, layout: :page
    end

    get '/docs' do
      haml :page do
        markdown :docs
      end
    end

    # /user/{name}.json
    # /user/{name}.xml
    get %r{/user/([a-zA-Z0-9\-_~.]+)\.(json|xml)} do |name, type|
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

    #/user/{name}/shouts.rss
    #/user/{name}/shouts.json
    #/user/{name}/shouts.xml
    get %r{/user/([a-zA-Z0-9\-_~.]+)/shouts\.(rss|json|xml)} do |name, type|
      set_content_type(type)
      cache("shouts:#{name}.#{type}") do
        case type
        when 'rss'
          @name = name.capitalize
          @resource = 'shouts'
          @link = "http://www.furaffinity.net/user/#{name}"
          @posts = @fa.shouts(name).map do |shout|
            @post = {
              title: "Shout from #{shout[:name]}",
              link: "http://www.furaffinity.net/user/#{name}/##{shout[:id]}",
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


    # /user/{name}/journals.rss
    # /user/{name}/journals.json
    # /user/{name}/journals.xml
    get %r{/user/([a-zA-Z0-9\-_~.]+)/journals\.(rss|json|xml)} do |name, type|
      set_content_type(type)
      cache("journals:#{name}.#{type}") do
        case type
        when 'rss'
          @name = name.capitalize
          @resource = 'journals'
          @link = "http://www.furaffinity.net/journals/#{name}/"
          @posts = @fa.journals(name).take(FAExport.config[:rss_limit]).map do |id|
            cache "journal:#{id}.rss" do
              @post = @fa.journal(id)
              @description = "<p>#{@post[:description]}</p>"
              builder :post
            end
          end
          builder :feed
        when 'json'
          JSON.pretty_generate @fa.journals(name)
        when 'xml'
          @fa.journals(name).to_xml(root: 'journals', skip_types: true)
        end
      end
    end

    # /user/{name}/gallery.rss
    # /user/{name}/gallery.json
    # /user/{name}/gallery.xml
    # /user/{name}/scraps.rss
    # /user/{name}/scraps.json
    # /user/{name}/scraps.xml
    get %r{/user/([a-zA-Z0-9\-_~.]+)/(gallery|scraps)\.(rss|json|xml)} do |name, folder, type|
      set_content_type(type)
      page = params[:page] =~ /^[0-9]+$/ ? params[:page] : 1
      cache("#{folder}:#{name}.#{type}?#{page}") do
        case type
        when 'rss'
          @name = name.capitalize
          @resource = folder.capitalize
          @link = "http://www.furaffinity.net/#{folder}/#{name}/"
          @posts = @fa.submissions(name, folder, 1).take(FAExport.config[:rss_limit]).map do |id|
            cache "submission:#{id}.rss" do
              @post = @fa.submission(id)
              @description = "<a href=\"#{@post[:link]}\"><img src=\"#{@post[:image]}"\
                             "\"/></a><br/><br/><p>#{@post[:description]}</p>"
              builder :post
            end
          end
          builder :feed
        when 'json'
          JSON.pretty_generate @fa.submissions(name, folder, page)
        when 'xml'
          @fa.submissions(name, folder, page).to_xml(root: 'submissions', skip_types: true)
        end
      end
    end

    # /submission/{id}.json
    # /submission/{id}.xml
    get %r{/submission/([0-9]+)\.(json|xml)} do |id, type|
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

    # /journal/{id}.json
    # /journal/{id}.xml
    get %r{/journal/([0-9]+)\.(json|xml)} do |id, type|
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

    # /submission/{id}/comments.json
    # /submission/{id}/comments.xml
    get %r{/submission/([0-9]+)/comments\.(json|xml)} do |id, type|
      set_content_type(type)
      cache("submissions_comments:#{id}.#{type}") do
        case type
        when 'json'
          JSON.pretty_generate @fa.submission_comments(id)
        when 'xml'
          @fa.submission_comments(id).to_xml(root: 'comments', skip_types: true)
        end
      end
    end

    # /journal/{id}/comments.json
    # /journal/{id}/comments.xml
    get %r{/journal/([0-9]+)/comments\.(json|xml)} do |id, type|
      set_content_type(type)
      cache("journal_comments:#{id}.#{type}") do
        case type
        when 'json'
          JSON.pretty_generate @fa.journal_comments(id)
        when 'xml'
          @fa.journal_comments(id).to_xml(root: 'comments', skip_types: true)
        end
      end
    end

    error FAStatusError do
      status 502
      env['sinatra.error'].message
    end

    error FASystemError do
      status 404
      env['sinatra.error'].message
    end

    error FALoginError do
      status 403
      env['sinatra.error'].message
    end

    error do
      status 500
      'FAExport encounter an internal error'
    end
  end
end
