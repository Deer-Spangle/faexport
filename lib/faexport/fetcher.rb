:style_unknown
:style_classic
:style_modern

class Fetcher
  attr_accessor :cache

  def initialize(cache, cookie)
    @cache = cache
    @cookie = cookie
    @safe_for_work = false
  end

  def fetch_html(path, extra_cookie = nil)
    url = fa_url(path)
    raw = @cache.add("url:#{url}:#{@cookie}:#{extra_cookie}") do
      open(url, 'User-Agent' => USER_AGENT, 'Cookie' => "#{@cookie};#{extra_cookie}") do |response|
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

    if raw.include?('has elected to make their content available to registered users only.')
      raise FALoginError.new(url)
    end

    if raw.include?('has voluntarily disabled access to their account and all of its contents.')
      raise FASystemError.new(url)
    end

    if raw.include?('<a href="/register"><strong>Create an Account</strong></a>')
      raise FALoginError.new(url)
    end

    # Parse and save the status, most pages have this, but watcher lists do not.
    parse_status(html)

    html
  end

  def fa_url(path)
    if path.to_s.start_with? "/"
      path = path[1..-1]
    end
    "#{fa_address}/#{path}"
  end

  def fa_address
    "https://#{@safe_for_work ? 'sfw' : 'www'}.furaffinity.net"
  end

  def parse_status(html)
    footer = html.css('.footer')
    center = footer.css('center')

    if footer.length == 0
      return
    end
    timestamp_line = footer[0].inner_html.split("\n").select{|line| line.strip.start_with? "Server Local Time: "}
    timestamp = timestamp_line[0].to_s.split("Time:")[1].strip

    counts = center.to_s.scan(/([0-9]+)\s*<b>/).map{|d| d[0].to_i}

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
    status_json = JSON.pretty_generate status
    @cache.save_status(status_json)
    status_json
  rescue
    # If we fail to read and save status, it's no big deal
  end

  def identify_style(html)
    stylesheet = html.at_css("head link[rel='stylesheet']")["href"]
    if stylesheet.start_with?("/themes/classic/")
      :style_classic
    elsif stylesheet.start_with?("/themes/beta")
      :style_modern
    else
      :style_unknown
    end
  end
end
