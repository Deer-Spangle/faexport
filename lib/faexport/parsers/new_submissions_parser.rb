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

class NewSubmissionsParser < Parser

  def initialize(fetcher, from_id)
    super(fetcher)
    @login_required = true
    @from_id = from_id
  end

  def get_path
    "msg/submissions/new" + (if @from_id.nil? then "" else "~#{@from_id}@72/" end)
  end

  def get_cache_key
    "new_submissions" + (if @from_id.nil? then "" else ":from:#{@from_id}" end)
  end

  def parse_classic(html, is_login)
    login_user = get_current_user_classic(html, fa_url(get_path))
    submissions = html.css('.gallery > figure').map{|art| build_submission_notification(art)}
    {
        "current_user": login_user,
        "new_submissions": submissions
    }
  end

private
  def build_submission_notification(elem)
    title_link = elem.css('a')[1]
    uploader_link = elem.css('a')[2]
    {
        id: last_path(title_link['href']),
        title: title_link.content.to_s,
        thumbnail: "https:#{elem.at_css('img')['src']}",
        link: fa_url(title_link['href'][1..-1]),
        name: uploader_link.content.to_s,
        profile: fa_url(uploader_link['href'][1..-1]),
        profile_name: last_path(uploader_link['href'])
    }
  end
end


