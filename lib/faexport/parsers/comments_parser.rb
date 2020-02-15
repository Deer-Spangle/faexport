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
            profile: @fetcher.fa_url(profile_url),
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
