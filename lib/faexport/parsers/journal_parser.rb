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


