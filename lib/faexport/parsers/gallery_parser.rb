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

class GalleryParser < Parser

  def initialize(fetcher, user, folder, offset)
    super(fetcher)
    @user = user
    @folder = folder
    @offset = offset

    # Check offset is valid for folder
    if offset.size > 1
      raise FAOffsetError.new(
          fa_url("#{folder}/#{escape(user)}/"),
          "You may only provide one of 'page', 'next' or 'prev' as a parameter")
    elsif folder == 'favorites' && offset[:page]
      raise FAOffsetError.new(
          fa_url("#{folder}/#{escape(user)}/"),
          "Due to a change by FurAffinity, favorites can no longer be accessed by page. See http://faexport.spangle.org.uk/docs#get-user-name-folder for more details.")
    elsif folder != 'favorites' && (offset[:next] || offset[:prev])
      raise FAOffsetError.new(
          fa_url("#{folder}/#{escape(user)}/"),
          "The options 'next' and 'prev' are only usable on favorites. Use 'page' instead with a page number")
    end
  end

  def get_path
    if @offset[:page]
      "#{@folder}/#{escape(@user)}/#{@offset[:page]}/"
    elsif @offset[:next]
      "#{@folder}/#{escape(@user)}/#{@offset[:next]}/next"
    elsif @offset[:prev]
      "#{@folder}/#{escape(@user)}/#{@offset[:prev]}/prev"
    else
      "#{@folder}/#{escape(@user)}/"
    end
  end

  def get_cache_key
    "gallery:#{get_path}"
  end

  def parse_classic(html, is_login)
    error_msg = html.at_css("table.maintable td.alt1 b")
    if !error_msg.nil? &&
        (error_msg.text == "The username \"#{@user}\" could not be found." ||
            error_msg.text == "User \"#{@user}\" was not found in our database.")
      raise FASystemError.new(fa_url(get_path))
    end

    html.css('.gallery > figure').map {|art| build_submission_classic(art)}
  end
end
