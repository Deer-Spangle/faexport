# frozen_string_literal: true

xml.instruct! :xml, version: "1.0"
xml.rss version: "2.0" do
  xml.channel do
    xml.title @name
    xml.description @info
    xml.link @link
    xml.generator "FAExport"
    xml << @posts.join("\n")
  end
end
