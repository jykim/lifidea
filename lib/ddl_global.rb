def get_code(group)
  begin
    SysCode.find_all_by_group(group).map{|e|[e.title,e.content]}
  rescue Exception => e
    error("[get_code] Error #{e}")
  end  
end

def get_config(title)
  begin
    SysConfig.find_by_title(title).content    
  rescue Exception => e
    error("[get_config] Error #{e}")
  end
end

def get_cur_time()
  Time.now.in_time_zone(TIMEZONE)
end

def cache_data(key, value = "none")
  #error "[cache_data] #{key}=#{value}"
  if value == "none"
    CACHE.get(ENV['RAILS_ENV']+'_'+key)
  else
    CACHE.set(ENV['RAILS_ENV']+'_'+key, value)
  end
end

def parse_value(value)
  return value if value.class != String
  begin
    eval(value)
  rescue Exception => e
    value
  end
end

def read_recent_file_in(path, o = {})
  file = find_in_path(path, o).map{|e|[e,File.new(e).mtime]}.sort_by{|e|e[1]}[-1]
  puts "[read_recent_file_in] #{file.inspect}"
  file[0]
end

# Read from CSV
# - assume more than two lines of file, with the header in the first line
# @return [Array<Hash<Symbol,String>>] : 
def read_csv(filename, o = {})
  #header = o[:header] || true
  content = FasterCSV.parse(IO.read(filename).to_lf, :row_sep => "\n")
  if o[:output] == :array
    content[1..-1]
  else
    content[1..-1].map{|c|content[0].map_hash_with_index{|h,i|[h.downcase.to_sym, c[i]]}}
  end
end

def write_csv(filename, content, o = {})
  mode = o[:mode] || 'w'
  if o[:summary]
    content << o[:summary].map_with_index{|e,i|
      case e.class.to_s
      when "String"
        e
      when "Symbol"
        content.map{|l|l[i]}.find_all{|e2|e2.respond_to?(:abs)}.send(e) if e
      end
    }
  end
  if o[:normalize]
    o[:normalize].each_with_index{|e,i|
      next if !e
      case e
      when :minmax
        max, min = content.map{|l|l[i]}.max, content.map{|l|l[i]}.min
        next if max == min
        content.each{|l|l[i] = (l[i] - min) / (max - min)}
      end
    }
  end
  content = [o[:header]].concat(content) if o[:header]
  File.open(filename, mode){|f|f.puts content.map{|e|e.to_csv}.join("")}
end

def info(str)
  puts str
  $lgr.info str if $lgr
end

def error(str, e = nil)
  str = [str, e.inspect,e.backtrace[0..5]].join("\n") if e
  puts str
  $lgr_e.error str if $lgr_e
  $lgr.error str if $lgr
end

def debug(str, header = "")
  puts str if header == ""
  $lgr.debug header + str if $lgr
end