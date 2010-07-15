load 'code/rs_library.rb'
require 'net/http'
require 'rexml/document'
require 'json/pure'
require "erb"
include ERB::Util
filename = ARGV[0] #'queries_chk.txt'

class WebSearchCollector
  def get_yahoo_results(query, o = {})
    result = []
    @search_type = "web"
    appid = "f9yVorbV34HgP6nBkjCkvnoENrNfwUM0R3KpdQG.jaWhhOJv984SstQRXMo-"
	search_uri = URI.parse("http://boss.yahooapis.com/ysearch/#{@search_type}/v1/=#{url_encode(query)}?count=10&abstract=long&format=xml&raw=true&lang=en&region=us&appid=#{appid}")
	#puts search_uri
	result_text = Net::HTTP.get(search_uri)
	xml_doc = REXML::Document.new(result_text)
	xml_doc.elements.each("*/*/result") do |e|
		result << e.elements["url"].text.strip
	end
    result
  end
  
  def get_google_results(query, o = {})
	size = o[:size] || 8
	offset = o[:offset] || 0
	search_uri = URI.parse("http://ajax.googleapis.com/ajax/services/search/web?v=1.0&rsz=#{size}&start=#{offset}&q=#{url_encode(query)}")
	#puts search_uri
	result_text = Net::HTTP.get(search_uri)
	JSON.parse(result_text)["responseData"]["results"].map{|e|e["unescapedUrl"]}
  end
  
  def get_bing_results(query, o = {})
	size = o[:size] || 10
	offset = o[:offset] || 0
	appid = "9E0807AEECA586DFCC6730438FA4DA6C0BE54B82"
	url = "http://api.bing.net/json.aspx?"                               + 
            "AppId=" + appid                                             + 
            "&Query=#{url_encode(query)}"                                + 
            "&Sources=Web"                                               + 
            "&Version=2.0"                                               + 
            "&Market=en-us"                                              + 
            "&Adult=Moderate"                                            + 
            "&Web.Count=#{size}"                                         + 
            "&Web.Offset=#{offset}"                                      + 
            "&Web.Options=DisableHostCollapsing+DisableQueryAlterations";
	puts url
	result_text = Net::HTTP.get(URI.parse(url))
	JSON.parse(result_text)["SearchResponse"]["Web"]["Results"].map{|e|e["Url"]}
  end
end

wsc = WebSearchCollector.new
['google','yahoo','bing'].each do |mode|
	File.open("#{filename}.#{mode}.#{Time.now.strftime('%Y%m%d')}.res", 'w') do |f|
		f.puts "Query\tDocument\tDocumentScore"
		IO.read(filename).split("\n").each_with_index do |q,i2|
			case mode
			when 'yahoo': wsc.get_yahoo_results(q).each_with_index{|e,i|f.puts "#{q.strip}\t#{e}\t#{10-i}"}
			when 'google'
				wsc.get_google_results(q).each_with_index{|e,i|f.puts "#{q.strip}\t#{e}\t#{10-i}"}
				sleep(1)
				wsc.get_google_results(q, :offset=>8, :size=>2).each_with_index{|e,i|f.puts "#{q.strip}\t#{e}\t#{2-i}"}
			when 'bing': wsc.get_bing_results(q).each_with_index{|e,i|f.puts "#{q.strip}\t#{e}\t#{10-i}"}
			end
			sleep(1)
			puts "Processing #{i2}th query... (#{mode})"
		end
	end
end
