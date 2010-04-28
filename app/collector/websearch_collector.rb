require 'ddl_include'
require 'net/http'
require 'rexml/document'
require "erb"
include ERB::Util

class WebSearchCollector < Collector
  def open_source()
    @appid = "f9yVorbV34HgP6nBkjCkvnoENrNfwUM0R3KpdQG.jaWhhOJv984SstQRXMo-"
    @search_type = case @src.uri
    when /^web/ : "web"
    when /^img/ : "images"
    end
  end
  
  def read_from_source(o = {})
    result = []
    @src.uri.split(":")[1].split("|").each do |query|
      doc_count = o[:doc_count] || 100
      0.upto((doc_count-1)/50) do |i|
        start_at = i * 50
        search_uri = URI.parse("http://boss.yahooapis.com/ysearch/#{@search_type}/v1/=#{url_encode(query)}?count=50&abstract=long&view=keyterms&start=#{start_at}&type=#{o[:type]}&format=xml&raw=true&lang=en&region=us&appid=#{@appid}")
        #puts search_uri
        result_text = Net::HTTP.get(search_uri)
        xml_doc = REXML::Document.new(result_text)
        xml_doc.elements.each("*/*/result") do |e|
          #debugger
          next if !e.elements["date"].text
          case @search_type
          when "web"
            tags = [] ; e.elements.each('*/*/term'){|e2|tags << e2.text}
            result << {:title=>e.elements["title"].text.clear_tags, :content=>e.elements["abstract"].text, :itype=>@src.itype,
              :did=>e.elements["url"].text, :uri=>e.elements["url"].text, :basetime=>Time.parse(e.elements["date"].text), :metadata=>{:tags=>tags.join(",")} }
          when "images"
            result << {:title=>e.elements["filename"].text, :content=>((e.elements["abstract"].text || '')+"<br><br><img src='#{e.elements["url"].text}'>"), :itype=>@src.itype,
              :did=>e.elements["url"].text, :uri=>e.elements["url"].text, :basetime=>Time.parse(e.elements["date"].text), :metadata=>{:format=>e.elements["format"].text, :webpage=>e.elements["refererurl"].text} }
          end
        end
      end
    end
    result
  end
end