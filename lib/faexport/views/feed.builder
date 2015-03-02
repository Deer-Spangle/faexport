xml.instruct! :xml, version: '1.0'
xml.rss version: '2.0' do
  xml.channel do
    xml.title @name
    xml.description "#{@name}'s #{@resource}"
    xml.link @link
    xml.generator 'FAExport'
    xml << @posts.join("\n")
  end
end
