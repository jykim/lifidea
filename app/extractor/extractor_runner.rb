require 'ddl_include'

# Extract stat between start_at and end_at
# - Iterate through each day, running daily/weekly/monthly rules accordingly
# @param <String> start_at : yyyymmdd
# @param <String> end_at : yyyymmdd
def create_stat_for(start_at, end_at)
  info "#{start_at}..#{end_at}"
  se =StatExtractor.new
  (Date.parse(start_at)..Date.parse(end_at)).each do |basedate|
    #puts "\n== [create_stat_for] #{basedate.to_s} =="
    Rule.stat_rules('day').each{|r|se.extract_stat(basedate.to_s, "day", r.rtype , r )}
    Rule.stat_rules('week').each{|r|se.extract_stat(basedate.to_s, "week", r.rtype , r )} if basedate.wday == 1
    Rule.stat_rules('month').each{|r|se.extract_stat(basedate.to_s, "month", r.rtype , r )} if basedate.day == 1
  end  
end

# Export stat in text format
def export_stat_for(unit, start_at, end_at)
  cond = ["unit = ? and basedate > ? and basedate < ?", unit, start_at, end_at] #Date.parse(start_at) , Date.parse(end_at)]
  rids = Rule.stat_rules.map(&:rid)
  #FOREACH DocType
  File.open("stat_#{unit}_#{start_at}_#{end_at}.txt","w") do |f|
    #debugger
    f.puts((['basedate'].concat rids).join("\t")+"\n")
    f.puts Stat.all(:conditions=>cond).group_by(&:basedate). # group by date
      map{|basedate,stats|[unit,basedate.to_ymd, rids.to_val(stats.map_hash{|e|[e.rid,e.content.to_f]}, :def_val=>nil)].flatten}. # turn into feature vector
        sort_by{|e|e[0]}.map{|e|e.join("\t")}.join("\n")
  end
end
