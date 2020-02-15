require_relative 'parser'

class HomeParser < Parser

  def initialize(fetcher)
    super(fetcher)
  end

  def get_path
    ""
  end

  def get_cache_key
    "home"
  end

  def parse_classic(html)
    groups = html.css('#frontpage > .old-table-emulation')
    data = groups.map do |group|
      group.css('figure').map{|art| build_submission_classic(art)}
    end
    {
        artwork: data[0],
        writing: data[1],
        music: data[2],
        crafts: data[3]
    }
  end
end

