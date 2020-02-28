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
    url = fa_url(get_path)
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
        profile: fa_url(profile['href'][1..-1]),
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
              profile: fa_url(profile['href'][1..-1]+"/"),
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


