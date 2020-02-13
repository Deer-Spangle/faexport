class UserProfileParser < Parser

  def initialize(fetcher, username)
    super(fetcher)
    @username = username
  end

  def get_url
    "/user/#{escape(@username)}"
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
        profile: fa_url(profile),
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
        featured_submission: build_submission(html.at_css('.userpage-featured-submission b')),
        profile_id: build_submission(html.at_css('#profilepic-submission b')),
        artist_information: select_artist_info(tables['Artist Information']),
        contact_information: select_contact_info(tables['Contact Information']),
        watchers: select_watchers_info(tables['Watched By'], 'watched-by'),
        watching: select_watchers_info(tables['Is Watching'], 'is-watching')
    }
  end
end