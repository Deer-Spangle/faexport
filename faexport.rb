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

require './lib/cache'
require './lib/scraper'
require 'active_support'
require 'active_support/core_ext'
require 'builder'
require 'rdiscount'
require 'sinatra'
require 'sinatra/json'
require 'yaml'

CACHE_TIME = 30 # Seconds
REDIS_URL = ENV['REDISTOGO_URL']
CONTENT_TYPES = {
  'json' => 'application/json',
  'xml' => 'application/xml',
  'rss' => 'application/rss+xml'
}
SETTINGS_FILE = 'settings.yml'
if File.exist?('settings.yml')
  SETTINGS = YAML.load_file('settings.yml')
else
  SETTINGS = { 'username' => ENV['FA_USERNAME'], 'password' => ENV['FA_PASSWORD'] }
end

CACHE = RedisCache.new(REDIS_URL, CACHE_TIME)
FA = Furaffinity.new(CACHE)
FA.login(SETTINGS['username'], SETTINGS['password'])

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
  content_type CONTENT_TYPES[type]
  CACHE.add("data:#{name}.#{type}") do
    case type
    when 'json'
      JSON.pretty_generate FA.user(name)
    when 'xml'
      FA.user(name).to_xml(root: 'user', skip_types: true)
    end
  end
end

#/user/{name}/shouts.rss
#/user/{name}/shouts.json
#/user/{name}/shouts.xml
get %r{/user/([a-zA-Z0-9\-_~.]+)/shouts\.(rss|json|xml)} do |name, type|
  content_type CONTENT_TYPES[type]
  CACHE.add("shouts:#{name}.#{type}") do
    case type
    when 'rss'
      @name = name.capitalize
      @resource = 'shouts'
      @link = "http://www.furaffinity.net/user/#{name}"
      @posts = FA.shouts(name).map do |shout|
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
      JSON.pretty_generate FA.shouts(name)
    when 'xml'
      FA.shouts(name).to_xml(root: 'shouts', skip_types: true)
    end
  end
end


# /user/{name}/journals.rss
# /user/{name}/journals.json
# /user/{name}/journals.xml
get %r{/user/([a-zA-Z0-9\-_~.]+)/journals\.(rss|json|xml)} do |name, type|
  content_type CONTENT_TYPES[type]
  CACHE.add("journals:#{name}.#{type}") do
    case type
    when 'rss'
      @name = name.capitalize
      @resource = 'journals'
      @link = "http://www.furaffinity.net/journals/#{name}/"
      @posts = FA.journals(name).map do |id|
        cache "journal:#{id}.rss" do
          @post = FA.journal(id)
          @description = "<p>#{@post[:description]}</p>"
          builder :post
        end
      end
      builder :feed
    when 'json'
      JSON.pretty_generate FA.journals(name)
    when 'xml'
      FA.journals(name).to_xml(root: 'journals', skip_types: true)
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
  content_type CONTENT_TYPES[type]
  page = params[:page] =~ /^[0-9]+$/ ? params[:page] : 1
  CACHE.add("#{folder}:#{name}.#{type}?#{page}") do
    case type
    when 'rss'
      @name = name.capitalize
      @resource = folder.capitalize
      @link = "http://www.furaffinity.net/#{folder}/#{name}/"
      @posts = FA.submissions(name, folder, page).map do |id|
        cache "submission:#{id}.rss" do
          @post = FA.submission(id)
          @description = "<a href=\"#{@post[:link]}\"><img src=\"#{@post[:image]}"\
                         "\"/></a><br/><br/><p>#{@post[:description]}</p>"
          builder :post
        end
      end
      builder :feed
    when 'json'
      JSON.pretty_generate FA.submissions(name, folder, page)
    when 'xml'
      FA.submissions(name, folder, page).to_xml(root: 'submissions', skip_types: true)
    end
  end
end

# /submission/{id}.json
# /submission/{id}.xml
get %r{/submission/([0-9]+)\.(json|xml)} do |id, type|
  content_type CONTENT_TYPES[type]
  CACHE.add("submission:#{id}.#{type}") do
    case type
    when 'json'
      JSON.pretty_generate FA.submission(id)
    when 'xml'
      FA.submission(id).to_xml(root: 'submission', skip_types: true)
    end
  end
end

# /journal/{id}.json
# /journal/{id}.xml
get %r{/journal/([0-9]+)\.(json|xml)} do |id, type|
  content_type CONTENT_TYPES[type]
  CACHE.add("journal:#{id}.#{type}") do
    case type
    when 'json'
      JSON.pretty_generate FA.journal(id)
    when 'xml'
      FA.journal(id).to_xml(root: 'journal', skip_types: true)
    end
  end
end

error FAError do
  status 404
  "FA returned an error page when trying to access #{env['sinatra.error'].url}."
end

error do
  status 500
  'FAExport encounter an internal error'
end

