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

class NotificationsParser < Parser

  def initialize(fetcher, include_deleted)
    super(fetcher)
    @login_required = true
    @include_deleted = include_deleted
  end

  def get_path
    "msg/others/"
  end

  def get_cache_key
    "notifications" + (if @include_deleted then ":inc_deleted" else "" end)
  end

  def parse_classic(html, is_login)
    notification_counts = html.css("a.notification-container").each do |elem|
      {
          title: elem['title'],
          count: Integer(elem['title'].gsub(",", "").split[0])
      }
    end
    # Create response
    {
        current_user: get_current_user_classic(html, fa_url(get_path)),
        notification_counts: {
            submissions: sum_notifications_with_word(notification_counts, "Submission"),
            comments: sum_notifications_with_word(notification_counts, "Comment"),
            journals: sum_notifications_with_word(notification_counts, "Journal"),
            favorites: sum_notifications_with_word(notification_counts, "Favorite"),
            watchers: sum_notifications_with_word(notification_counts, "Watch"),
            notes: sum_notifications_with_word(notification_counts, "Unread Note"),
            trouble_tickets: sum_notifications_with_word(notification_counts, "Trouble Ticket")
        },
        new_watches: classic_new_watches(html),
        new_submission_comments: classic_new_submission_comments(html),
        new_journal_comments: classic_new_journal_comments(html),
        new_shouts: classic_new_shouts(html),
        new_favorites: classic_new_favorites(html),
        new_journals: classic_new_journals(html)
    }
  end

private
  def sum_notifications_with_word(notifications, word)
    notifications
        .select{|notification| notification[:title].include? word}
        .map{|notification| notification[:count]}
        .sum
  end

  def classic_new_watches(html)
    watches_elem = html.at_css("ul#watches")
    if watches_elem
      new_watches = []
      watches_elem.css("li:not(.section-controls)").each do |elem|
        if elem.at_css("input")['checked'] == "checked"
          if @include_deleted
            new_watches << {
                watch_id: "",
                name: "Removed by the user",
                profile: "",
                profile_name: "",
                avatar: fa_url(elem.at_css("img")['src']),
                posted: "",
                posted_at: ""
            }
          end
          next
        end
        date = pick_date(elem.at_css('.popup_date'))
        new_watches << {
            watch_id: elem.at_css("input")['value'],
            name: elem.at_css("span").content,
            profile: fa_url(elem.at_css("a")['href']),
            profile_name: last_path(elem.at_css("a")['href']),
            avatar: "https:#{elem.at_css("img")['src']}",
            posted: date,
            posted_at: to_iso8601(date)
        }
      end
      new_watches
    else
      []
    end
  end

  def classic_new_submission_comments(html)
    submission_comments_elem = html.at_css("fieldset#messages-comments-submission")
    if submission_comments_elem
      submission_comments_elem.css("li:not(.section-controls)").each do |elem|
        classic_comment_notification(elem, "submission")
      end.compact
    else
      []
    end
  end

  def classic_new_journal_comments(html)
    journal_comments_elem = html.at_css("fieldset#messages-comments-journal")
    if journal_comments_elem
      journal_comments_elem.css("li:not(.section-controls)").each do |elem|
        classic_comment_notification(elem, "journal")
      end.compact
    else
      []
    end
  end

  def classic_comment_notification(elem, post_type)
    if elem.at_css("input")['checked'] == "checked"
      if @include_deleted
        {
            comment_id: "",
            name: "Comment or the #{post_type} it was left on has been deleted",
            profile: "",
            profile_name: "",
            is_reply: false,
            "your_#{post_type}".to_sym => false,
            "their_#{post_type}".to_sym => false,
            "#{post_type}_id".to_sym => "",
            title: "Comment or the #{post_type} it was left on has been deleted",
            posted: "",
            posted_at: ""
        }
      else
        nil
      end
    else
      elem_links = elem.css("a")
      date = pick_date(elem.at_css('.popup_date'))
      is_reply = elem.to_s.include?("<em>your</em> comment on")
      {
        comment_id: elem.at_css("input")['value'],
        name: elem_links[0].content,
        profile: fa_url(elem_links[0]['href']),
        profile_name: last_path(elem_links[0]['href']),
        is_reply: is_reply,
        "your_#{post_type}".to_sym => !is_reply || elem.css('em').length == 2 && elem.css('em').last.content == "your",
        "their_#{post_type}".to_sym => elem.css('em').last.content == "their",
        "#{post_type}_id".to_sym => elem_links[1]['href'].split("/")[-2],
        title: elem_links[1].content,
        posted: date,
        posted_at: to_iso8601(date)
    }
    end
  end

  def classic_new_shouts(html)
    new_shouts = []
    shouts_elem = html.at_css("fieldset#messages-shouts")
    if shouts_elem
      shouts_elem.css("li:not(.section-controls)").each do |elem|
        if elem.at_css("input")['checked'] == "checked"
          if @include_deleted
            new_shouts << {
                shout_id: "",
                name: "Shout has been removed from your page",
                profile: "",
                profile_name: "",
                posted: "",
                posted_at: ""
            }
          end
          next
        end
        date = pick_date(elem.at_css('.popup_date'))
        new_shouts << {
            shout_id: elem.at_css("input")['value'],
            name: elem.at_css("a").content,
            profile: fa_url(elem.at_css("a")['href']),
            profile_name: last_path(elem.at_css("a")['href']),
            posted: date,
            posted_at: to_iso8601(date)
        }
      end
    end
  end

  def classic_new_favorites(html)
    new_favorites = []
    favorites_elem = html.at_css("ul#favorites")
    if favorites_elem
      favorites_elem.css("li:not(.section-controls)").each do |elem|
        if elem.at_css("input")['checked'] == "checked"
          if @include_deleted
            new_favorites << {
                favorite_notification_id: "",
                name: "The favorite this notification was for has since been removed by the user",
                profile: "",
                profile_name: "",
                submission_id: "",
                submission_name: "The favorite this notification was for has since been removed by the user",
                posted: "",
                posted_at: ""
            }
          end
          next
        end
        elem_links = elem.css("a")
        date = pick_date(elem.at_css('.popup_date'))
        new_favorites << {
            favorite_notification_id: elem.at_css("input")["value"],
            name: elem_links[0].content,
            profile: fa_url(elem_links[0]['href']),
            profile_name: last_path(elem_links[0]['href']),
            submission_id: last_path(elem_links[1]['href']),
            submission_name: elem_links[1].content,
            posted: date,
            posted_at: to_iso8601(date)
        }
      end
    end
  end

  def classic_new_journals(html)
    new_journals = []
    journals_elem = html.at_css("ul#journals")
    if journals_elem
      journals_elem.css("li:not(.section-controls)").each do |elem|
        # Deleted journals are only displayed when the poster's page has been deactivated
        if elem.at_css("input")['checked'] == "checked"
          if @include_deleted
            new_journals << {
                favorite_notification_id: "",
                name: "This journal has been removed by the poster",
                profile: "",
                profile_name: "",
                submission_id: "",
                submission_name: "This journal has been removed by the poster",
                posted: "",
                posted_at: ""
            }
          end
          next
        end
        elem_links = elem.css("a")
        date = pick_date(elem.at_css('.popup_date'))
        new_journals << {
            journal_id: elem.at_css("input")['value'],
            title: elem_links[0].content,
            name: elem_links[1].content,
            profile: fa_url(elem_links[1]['href']),
            profile_name: last_path(elem_links[1]['href']),
            posted: date,
            posted_at: to_iso8601(date)
        }
      end
    end
  end
end
