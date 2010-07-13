load 'code/rs_library.rb'
require 'net/http'
require 'rexml/document'
require 'json/pure'
require "erb"
include ERB::Util
filename = 'queries_chk.txt'

wsc = WebSearchCollector.new

['google','yahoo'].each do |mode|
	File.open("#{filename}.#{mode}.#{Time.now.strftime('%Y%m%d')}.res", 'w') do |f|
		f.puts "Query\tDocument\tDocumentScore"
		IO.read(filename).split("\n").each_with_index do |q,i2|
			case mode
			when 'yahoo': wsc.get_yahoo_results(q).each_with_index{|e,i|f.puts "#{q.strip}\t#{e}\t#{10-i}"}
			when 'google'
				wsc.get_google_results(q).each_with_index{|e,i|f.puts "#{q.strip}\t#{e}\t#{10-i}"}
				sleep(1)
				wsc.get_google_results(q, :offset=>8, :size=>2).each_with_index{|e,i|f.puts "#{q.strip}\t#{e}\t#{2-i}"}
			end
			sleep(1)
			puts "Processing #{i2}th query... (#{mode})"
		end
	end
end
