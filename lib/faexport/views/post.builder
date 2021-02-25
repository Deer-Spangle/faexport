xml.item do
  xml.title @post[:title]
  xml.link @post[:link]
  xml.description @description
  xml.pubDate Time.parse(@post[:posted] + ' UTC').rfc822
  xml.guid @post[:link]
  (@post[:keywords] || []).each { |k| xml.category k }
end
