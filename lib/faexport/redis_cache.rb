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

  def save_status(status)
    @redis.set("#status", status)
    @redis.expire("#status", @expire)
  end

  def remove(key)
    @redis.del(key)
  end
end