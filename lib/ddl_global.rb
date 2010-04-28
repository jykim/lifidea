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

def get_features_by_type(type)
  case type
  when 'con' : Searcher::CON_FEATURES
  when 'doc' : Searcher::DOC_FEATURES
  when 'csel' : RubySearcher::CS_TYPES
  end
end

def clear_webpage(html)
  return "" if !html
  hpricot = Hpricot(html)
  hpricot.search("script").remove
  hpricot.search("link").remove
  hpricot.search("meta").remove
  hpricot.search("style").remove
  hpricot.inner_text.gsub(/\s{5,}/,"\n")
end

# - Do not use cached data when executing a task
def cache_data(key, value = "none")
  #error "[cache_data] #{key}=#{value}"
  trial = 0
  if value == "none"
    if $task_flag
      $cache[ENV['RAILS_ENV']+'_'+key]
    else
      CACHE.get(ENV['RAILS_ENV']+'_'+key)
    end
  else
    if $task_flag
      $cache[ENV['RAILS_ENV']+'_'+key] = value
    else
      CACHE.set(ENV['RAILS_ENV']+'_'+key, value)
    end
    value
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

def info(str)
  return if $lgr.level > Logger::INFO
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
  return if $lgr.level > Logger::DEBUG
  puts str if header == ""
  $lgr.debug header + str if $lgr
end