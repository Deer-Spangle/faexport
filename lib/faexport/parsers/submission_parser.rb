# encoding: utf-8

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

class SubmissionParser < Parser

  def initialize(fetcher, id)
    super(fetcher)
    @id = id
  end

  def get_path
    "/view/#{@id}/"
  end

  def get_cache_key
    "submission:#{@id}"
  end

  def parse_classic(html, is_login)
    error_msg = html.at_css("table.maintable td.alt1")
    if !error_msg.nil? && error_msg.content.strip == "You are not allowed to view this image due to the content filter settings."
      raise FASystemError.new(get_path)
    end

    submission = html.css('div#page-submission table.maintable table.maintable')[-1]
    submission_title = submission.at_css(".classic-submission-title")
    raw_info = submission.at_css('td.alt1')
    info = raw_info.content.lines.map{|i| i.gsub(/^\p{Space}*/, '').rstrip}
    keywords = raw_info.css('div#keywords a')
    date = pick_date(raw_info.at_css('.popup_date'))
    img = html.at_css('img#submissionImg')
    actions_bar = html.css('#page-submission td.alt1 div.actions a')
    download_url = "https:" + actions_bar.select {|a| a.content == "Download" }.first['href']
    profile_url = html.at_css('td.cat a')['href'][1..-1]
    og_thumb = html.at_css('meta[property="og:image"]')
    thumb_img = if og_thumb.nil? || og_thumb['content'].include?("/banners/fa_logo")
                  img ? "https:" + img['data-preview-src'] : nil
                else
                  og_thumb['content'].sub! "http:", "https:"
                end

    submission = {
        title: submission_title.at_css('h2').content,
        description: submission.css('td.alt1')[2].children.to_s.strip,
        description_body: submission.css('td.alt1')[2].children.to_s.strip,
        name: html.css('td.cat a')[1].content,
        profile: fa_url(profile_url),
        profile_name: last_path(profile_url),
        avatar: "https:#{submission_title.at_css("img.avatar")['src']}",
        link: fa_url("view/#{@id}/"),
        posted: date,
        posted_at: to_iso8601(date),
        download: download_url,
        full: img ? "https:" + img['data-fullview-src'] : nil,
        thumbnail: thumb_img,
        category: field(info, 'Category'),
        theme: field(info, 'Theme'),
        species: field(info, 'Species'),
        gender: field(info, 'Gender'),
        favorites: field(info, 'Favorites'),
        comments: field(info, 'Comments'),
        views: field(info, 'Views'),
        resolution: field(info, 'Resolution'),
        rating: raw_info.at_css('div img')['alt'].gsub(' rating', ''),
        keywords: keywords ? keywords.map(&:content).reject(&:empty?) : []
    }

    if is_login
      fav_link = actions_bar.select {|a| a.content.end_with? "Favorites" }.first
      fav_status = fav_link.content.start_with?("-Remove")
      fav_key = fav_link['href'].split("?key=")[-1]

      submission[:fav_status] = fav_status
      submission[:fav_key] = fav_key
    end

    submission
  end

  def field(info, field)
    # Most often, fields just show up in the format "Field: value"
    value = info.map{|i| i[/^#{field}: (.+)$/, 1]}.compact.first
    return value if value

    # However, they also can be "Field:" "value"
    info.each_with_index do |i, index|
      return info[index + 1] if i =~ /^#{field}:$/
    end
    nil
  end
end
