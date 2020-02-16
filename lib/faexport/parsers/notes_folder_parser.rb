require_relative 'parser'

class NotesFolderParser < Parser

  def initialize(fetcher, folder, page)
    super(fetcher)
    @folder_str = {
        inbox: "inbox",
        outbox: "outbox",
        unread: "unread",
        archive: "archive",
        trash: "trash",
        high: "high_prio",
        medium: "medium_prio",
        low: "low_prio"
    }[folder.to_sym]
    @page = page
  end

  def get_path
    "msg/pms/#{@page}/"
  end

  def get_extra_cookie
    "folder=#{@folder_str}"
  end

  def get_cache_key
    "notes_folder:#{@folder_str}:#{@page}:#{@fetcher.cookie}"
  end

  def parse_classic(html)
    notes_table = html.at_css("table#notes-list")
    notes_table.css("tr.note").map do |note|
      subject = note.at_css("td.subject")
      profile_from = note.at_css("td.col-from")
      profile_to = note.at_css("td.col-to")
      date = pick_date(note.at_css("span.popup_date"))
      if profile_to.nil?
        is_inbound = true
        profile = profile_from.at_css("a")
      else
        if profile_from.nil?
          is_inbound = false
          profile = profile_to.at_css("a")
        else
          is_inbound = profile_to.content.strip == "me"
          profile = is_inbound ? profile_from.at_css("a") : profile_to.at_css("a")
        end
      end
      {
          note_id: note.at_css("input")['value'].to_i,
          subject: subject.at_css("a.notelink").content,
          is_inbound: is_inbound,
          is_read: subject.at_css("a.notelink.note-unread").nil?,
          name: profile.content,
          profile: @fetcher.fa_url(profile['href'][1..-1]),
          profile_name: last_path(profile['href']),
          posted: date,
          posted_at: to_iso8601(date)
      }
    end
  end
end


