require_relative 'parser'

class JournalParser < Parser

  def initialize(fetcher, journal_id)
    super(fetcher)
    @journal_id = journal_id
  end

  def get_path
    "journal/#{@journal_id}/"
  end

  def get_cache_key
    "journal:#{@journal_id}"
  end

  def parse_classic(html)
    date = pick_date(html.at_css('td.cat .journal-title-box .popup_date'))
    profile_url = html.at_css('td.cat .journal-title-box a')['href'][1..-1]
    journal_header = nil
    journal_header = html.at_css('.journal-header').children[0..-3].to_s.strip unless html.at_css('.journal-header').nil?
    journal_footer = nil
    journal_footer = html.at_css('.journal-footer').children[2..-1].to_s.strip unless html.at_css('.journal-footer').nil?

    {
        title: html.at_css('td.cat b').content.gsub(/\A[[:space:]]+|[[:space:]]+\z/, ''),
        description: html.at_css('td.alt1 div.no_overflow').children.to_s.strip,
        journal_header: journal_header,
        journal_body: html.at_css('.journal-body').children.to_s.strip,
        journal_footer: journal_footer,
        name: html.at_css('td.cat .journal-title-box a').content,
        profile: fa_url(profile_url),
        profile_name: last_path(profile_url),
        avatar: "https:#{html.at_css("img.avatar")['src']}",
        link: fa_url("journal/#{@journal_id}/"),
        posted: date,
        posted_at: to_iso8601(date)
    }
  end
end


