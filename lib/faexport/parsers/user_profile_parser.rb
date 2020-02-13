require 'faexport/parsers/parser'

class UserProfileParser < Parser

  def initialize(fetcher, username)
    super(fetcher)
    @username = username
  end

  def get_path
    "/user/#{escape(@username)}/"
  end

  def get_cache_key
    "user_profile:#{@username}"
  end

  def parse_classic(html)
    info = html.css('.ldot')[0].children.to_s
    stats = html.css('.ldot')[1].children.to_s
    date = html_field(info, 'Registered Since')
    user_title = html_field(info, 'User Title')
    tables = {}
    html.css('table.maintable').each do |table|
      title = table.at_css('td.cat b')
      tables[title.content.strip] = table if title
    end

    {
        id: nil,
        name: html.at_css('.addpad.lead b').content[1..-1],
        profile: @fetcher.fa_url(get_path),
        account_type: html.at_css('.addpad.lead').content[/\((.+?)\)/,1].strip,
        avatar: "https:#{html.at_css('td.addpad img')['src']}",
        full_name: html.at_css("title").content[/Userpage of(.+?)--/,1].strip,
        artist_type: user_title, # Backwards compatibility
        user_title: user_title,
        registered_since: date,
        registered_at: to_iso8601(date),
        current_mood: html_field(info, 'Current Mood'),
        artist_profile: html_long_field(info, 'Artist Profile'),
        pageviews: html_field(stats, 'Page Visits'),
        submissions: html_field(stats, 'Submissions'),
        comments_received: html_field(stats, 'Comments Received'),
        comments_given: html_field(stats, 'Comments Given'),
        journals: html_field(stats, 'Journals'),
        favorites: html_field(stats, 'Favorites'),
        featured_submission: build_submission_classic(html.at_css('.userpage-featured-submission b')),
        profile_id: build_submission_classic(html.at_css('#profilepic-submission b')),
        artist_information: select_artist_info_classic(tables['Artist Information']),
        contact_information: select_contact_info_classic(tables['Contact Information']),
        watchers: select_watchers_info_classic(tables['Watched By'], 'watched-by'),
        watching: select_watchers_info_classic(tables['Is Watching'], 'is-watching')
    }
  end

  private
  def html_field(info, field)
    (info[/<b[^>]*>#{field}:<\/b>(.+?)<br>/, 1] || '').gsub(%r{</?[^>]+?>}, '').strip
  end

  def html_long_field(info, field)
    (info[/<b[^>]*>#{field}:<\/b><br>(.+)/m, 1] || '').strip
  end

  def select_artist_info_classic(elem)
    elem = elem.at_css('td.alt1') if elem
    return nil unless elem
    info = {}
    elem.children.to_s.scan(/<strong>\s*(.*?)\s*<\/strong>\s*:\s*(.*?)\s*<\/div>/).each do |match|
      info[match[0]] = match[1]
    end
    info
  end

  def select_contact_info_classic(elem)
    elem = elem.at_css('td.alt1') if elem
    return nil unless elem
    elem.css('div.classic-contact-info-item').map do |item|
      link_elem = item.at_css('a')
      {
          title: item.at_css('strong').content.gsub(/:\s*$/, ''),
          name: (link_elem || item.xpath('child::text()').to_s.squeeze(' ').strip),
          link: link_elem ? link_elem['href'] : ''
      }
    end
  end

  def select_watchers_info_classic(elem, selector)
    users = elem.css("##{selector} a").map do |user|
      link = @fetcher.fa_url(user['href'][1..-1])
      {
          name: user.at_css('.artist_name').content.strip,
          profile_name: last_path(link),
          link: link
      }
    end
    {
        count: elem.at_css('td.cat a').content[/([0-9]+)/, 1].to_i,
        recent: users
    }
  end
end