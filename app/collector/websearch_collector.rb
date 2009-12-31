require 'ddl_include'
require 'net/http'
require 'rexml/document'
require "erb"
include ERB::Util

class WebSearchCollector < Collector
  def open_source()
    @appid = "f9yVorbV34HgP6nBkjCkvnoENrNfwUM0R3KpdQG.jaWhhOJv984SstQRXMo-"
  end
  
  def read_from_source(o = {})
    result = []
    @src.uri.split("|").each do |query|
      doc_count = o[:doc_count] || 100
      0.upto((doc_count-1)/50) do |i|
        start_at = i * 50
        result_text = Net::HTTP.get(URI.parse("http://boss.yahooapis.com/ysearch/web/v1/=#{url_encode(query)}?count=50&abstract=long&view=keyterms&start=#{start_at}&type=#{o[:type]}&format=xml&raw=true&lang=en&region=us&appid=#{@appid}"))
        xml_doc = REXML::Document.new(result_text)
        xml_doc.elements.each("*/*/result") do |e|
          #debugger
          tags = [] ; e.elements.each('*/*/term'){|e2|tags << e2.text}
          result << {:title=>e.elements["title"].text, :content=>e.elements["abstract"].text, 
            :did=>e.elements["url"].text, :uri=>e.elements["url"].text, :basetime=>Time.parse(e.elements["date"].text), :metadata=>{:tags=>tags.join(",")} }
        end
      end
    end
    result
  end
end