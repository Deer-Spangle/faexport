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

class ShoutsParser < Parser

  def initialize(fetcher, user)
    super(fetcher)
    @user = user
  end

  def get_path
    "user/#{escape(@user)}/"
  end

  def get_cache_key
    "shouts:#{@user}"
  end

  def parse_classic(html)
    html.xpath('//table[starts-with(@id, "shout")]').map do |shout|
      name = shout.at_css('td.lead.addpad a')
      date = pick_date(shout.at_css('.popup_date'))
      profile_url = name['href'][1..-1]
      {
          id: shout.attr('id'),
          name: name.content,
          profile: fa_url(profile_url),
          profile_name: last_path(profile_url),
          avatar: "https:#{shout.at_css('td.alt1.addpad img')['src']}",
          posted: date,
          posted_at: to_iso8601(date),
          text: shout.css('.no_overflow.alt1')[0].children.to_s.strip
      }
    end
  end
end

