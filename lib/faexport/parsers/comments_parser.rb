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

class CommentsParser < Parser

  def initialize(fetcher, page_type, page_id, include_hidden)
    super(fetcher)
    @page_type = page_type
    @page_id = page_id
    @include_hidden = include_hidden
  end

  def get_path
    root_path =
        case @page_type
        when :submission_comments
          "view"
        when :journal_comments
          "journal"
        else
          raise FAInputError.new("Invalid page type specified for comments parser.")
        end
    "/#{root_path}/#{@page_id}/"
  end

  def get_cache_key
    "comments:#{@page_type}:#{@page_id}:#{@include_hidden}"
  end

  def parse_classic(html)
    comments = html.css('table.container-comment')
    reply_stack = []
    comments.map do |comment|
      has_timestamp = !!comment.attr('data-timestamp')
      id = comment.attr('id').gsub('cid:', '')
      width = comment.attr('width')[0..-2].to_i

      while reply_stack.any? && reply_stack.last[:width] <= width
        reply_stack.pop
      end
      reply_to = reply_stack.any? ? reply_stack.last[:id] : ''
      reply_level = reply_stack.size
      reply_stack.push({id: id, width: width})

      if has_timestamp
        date = pick_date(comment.at_css('.popup_date'))
        profile_url = comment.at_css('ul ul li a')['href'][1..-1]
        {
            id: id,
            name: comment.at_css('.replyto-name').content.strip,
            profile: fa_url(profile_url),
            profile_name: last_path(profile_url),
            avatar: "https:#{comment.at_css('.icon img')['src']}",
            posted: date,
            posted_at: to_iso8601(date),
            text: comment.at_css('.message-text').children.to_s.strip,
            reply_to: reply_to,
            reply_level: reply_level,
            is_deleted: false
        }
      elsif @include_hidden
        {
            id: id,
            text: comment.at_css('strong').content,
            reply_to: reply_to,
            reply_level: reply_level,
            is_deleted: true
        }
      else
        nil
      end
    end.compact
  end
end
