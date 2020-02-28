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
          profile: fa_url(profile['href'][1..-1]),
          profile_name: last_path(profile['href']),
          posted: date,
          posted_at: to_iso8601(date)
      }
    end
  end
end


