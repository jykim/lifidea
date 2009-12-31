require 'ddl_include'
require "csv"
require 'find'
require 'ftools'
  
# Collect from Log files
# = Type of sources
#  - money : Bank of America Statement
#  - app_log : RescueTime desktop activity log
class LogCollector < Collector
  FILES_IN_BATCH = 50 # Max. no of files processsed at a time
  
  def self.get_fixture_file(file_name, folder_name = "sources")
    File.join(RAILS_ROOT, "test", "fixtures", folder_name ,file_name)
  end
  
  def read_from_source(o = {})
    data_path = @src.uri.gsub("file://","")
    puts "Working on #{@src.title} (#{data_path}) #{@src}"
    result = [] ; file_count = 0
    #debugger
    find_in_path(data_path, :recursion=>true) do |fp, fn|
      break if file_count > FILES_IN_BATCH ; file_count += 1
      debug "[LogCollector#read_from_source] Working on #{fp}"

      begin
        result << case @src.itype
        when 'money_log'
          content = CSV.read(fp)[8..-1] ; next if !content
          content.map{|e|{:itype=>@src.itype, :title=>e[1], :metadata=>{:filename=>fp,:amount=>e[2].to_f,:balance=>e[3].to_f}, 
            :did=>[e[0],e[1],e[3]].to_id, :basetime=>Time.parse(e[0])}}.find_all{|e|!(e[:title] =~ /KEEP THE CHANGE TRANSFER/)}
        when 'app_log'
          content = YAML::load(IO.read(fp)); next if !content
          content.map do |e|
            e = e.to_options.map_hash{|k,v|[k,v.to_localtime]} #.delete(:extended_info)
            #debugger
            next if e.class != Hash
            {:itype=>@src.itype, :title=>e[:app_name],:did=>[e[:app_name], e[:start_time]].to_id,:basetime=>e[:start_time], 
              :metadata=>e.merge(:filename=>fp)}
          end
        end
      rescue Exception => e
        error "[LogCollector::read_from_source] error in #{fp}", e
        next
      end
      File.move(fp, "#{File.dirname(fp)}_bak")
    end#find
    result.collapse  
  end
end