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
      $cache[Rails.env+'_'+key]
    else
      CACHE.get(Rails.env+'_'+key)
    end
  else
    if $task_flag
      $cache[Rails.env+'_'+key] = value
    else
      CACHE.set(Rails.env+'_'+key, value)
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

