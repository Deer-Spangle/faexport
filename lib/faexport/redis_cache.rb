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
    if e.message.include? 'OOM'
      raise CacheError.new('The page returned from FA was too large to fit in the cache')
    else
      raise CacheError.new("Error accessing Redis Cache: #{e.message}")
    end
  end

  def add_hash(key, wait_long = false)
    get_and_parse(key) ||
        begin
          value = yield
          @redis.set(key, value.to_json)
          @redis.expire(key, wait_long ? @long_expire : @expire)
          value
        end
  rescue Redis::BaseError => e
    if e.message.include? 'OOM'
      raise CacheError.new('The page returned from FA was too large to fit in the cache')
    else
      raise CacheError.new("Error accessing Redis Cache: #{e.message}")
    end
  end

  def get_and_parse(key)
    json_data = @redis.get(key)
    JSON.parse(json_data, :symbolize_names => true) unless json_data.nil?
  end

  def save_status(status)
    @redis.set("#status", status)
    @redis.expire("#status", @expire)
  end

  def remove(key)
    @redis.del(key)
  end
end