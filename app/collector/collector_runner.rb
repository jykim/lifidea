require 'ddl_include'

$collectors = {}

def get_collector(src)
  return $collectors[src.id] if $collectors[src.id]
  debug "Generating new collector #{src.title}"
  $collectors[src.id] = case src.uri
  when /^http/ : RSSCollector.new(src)
  when /^webcal/ : ICALCollector.new(src)
  when /^file/
    if src.itype =~ /_log$/
      LogCollector.new(src)
    else
      FileCollector.new(src)
    end
  when /^imap/ : IMAPCollector.new(src)
  else
    WebSearchCollector.new(src)
  end
end

def run_collector(o = {})
  counts = {}
  Source.active.each do |src|
    next if (o[:source] && o[:source].to_i != src.id)   ||
            (o[:itype]  && o[:itype] != src.itype)      || src.uri.blank?
    collector = get_collector(src)
    begin
      counts[src.title] = collector.collect(o)
    rescue Exception => e
      error [e.inspect,e.backtrace[0..5]].join("\n")
    end
  end
  counts = counts.find_all{|k,v|v && v > 0}.to_hash
  warn "[run_collector] #{counts.values.sum} collected (#{counts.inspect})"
  counts.values.sum
end
