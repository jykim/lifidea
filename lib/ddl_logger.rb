
def info(str)
  return if $lgr.level > Logger::INFO
  puts str
  $lgr.info str if $lgr
end

def error(str, e = nil)
  str = [str, e.inspect,e.backtrace[0..5].map{|e|"  | #{e}"}].join("\n") if e
  puts str
  $lgr_e.error str if $lgr_e
  $lgr.error str if $lgr
end

def debug(str, header = "")
  return if $lgr.level > Logger::DEBUG
  puts str if header == ""
  $lgr.debug header + str if $lgr
end
