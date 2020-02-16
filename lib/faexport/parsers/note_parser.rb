require_relative 'parser'

class NoteParser < Parser

  def initialize(fetcher, note_id)
    super(fetcher)
    @note_id = note_id
  end

  def get_path
    "msg/pms/1/#{@note_id}/"
  end

  def get_cache_key
    "note:#{@note_id}:#{@fetcher.cookie}"
  end

  def parse_classic(html)
    url = @fetcher.fa_url(get_path)
    current_user = get_current_user_classic(html, url)
    note_table = html.at_css(".note-view-container table.maintable table.maintable")
    if note_table.nil?
      raise FASystemError.new(url)
    end
    note_header = note_table.at_css("td.head")
    note_from = note_header.css("em")[1].at_css("a")
    note_to = note_header.css("em")[2].at_css("a")
    is_inbound = current_user[:profile_name] == last_path(note_to['href'])
    profile = is_inbound ? note_from : note_to
    date = pick_date(note_table.at_css("span.popup_date"))
    description = note_table.at_css("td.text")
    desc_split = description.inner_html.split("—————————")
    {
        note_id: @note_id,
        subject: note_header.at_css("em.title").content,
        is_inbound: is_inbound,
        name: profile.content,
        profile: @fetcher.fa_url(profile['href'][1..-1]),
        profile_name: last_path(profile['href']),
        posted: date,
        posted_at: to_iso8601(date),
        avatar: "https#{note_table.at_css("img.avatar")['src']}",
        description: description.inner_html.strip,
        description_body: html_strip(desc_split.first.strip),
        preceding_notes: desc_split[1..-1].map do |note|
          note_html = Nokogiri::HTML(note)
          profile = note_html.at_css("a.linkusername")
          {
              name: profile.content.to_s,
              profile: @fetcher.fa_url(profile['href'][1..-1]+"/"),
              profile_name: last_path(profile['href']),
              description: note,
              description_body: html_strip(note.to_s.split("</a>:")[1..-1].join("</a>:"))
          }
        end
    }
  end

  def html_strip(html_s)
    html_s.gsub(/^(<br ?\/?>|\\r|\\n|\s)+/, "").gsub(/(<br ?\/?>|\\r|\\n|\s)+$/,"")
  end
end


