$rails_env ||= (ARGV[1] || "production")
$command ||= ARGV[0]

require File.dirname(__FILE__) + "/../../lib/daemon_include.rb"

while($running) do
  procs = {}
  `ps -U #{ENV['USER']} -o user,pid,cpu,pmem,time,command`.split("\n").each do |e|
    row = e.split(/\s+/)
    procs[row[1]] = {:user=>row[0],:cpu=>row[2],:pmem=>row[3],:time=>row[4],:cmd=>row[5..-1].join(" ")}
  end
  # @TODO make it environment-aware ;  v[:cmd] =~ /#{$rails_env}/ && 
  target_procs = procs.find_all{|k,v|v[:user] == ENV['USER'] && (v[:cmd] =~ /\.rb/ || v[:cmd] =~ /memcache/ || v[:cmd] =~ /solr/ || v[:cmd] =~ /ruby.*?server/) && !(v[:cmd] =~ /manager\.rb|_monitor/)}
  target_procs.each do |e|
    if $command == 'killall'
      `kill -9 #{e[0]}` ; puts "Killing #{e[0]}/#{e[1][:cmd]}"
    else
      puts e.inspect
    end
  end
  puts 'No process running!' if target_procs.size == 0
  docs_for_day = Item.all(:conditions=>['created_at > ?',Time.now.yesterday]).size
  Notifier.deliver_warning!("No document for Day!") if docs_for_day == 0
  
  if ARGV.size == 0 && $0 == __FILE__ 
    sleep 500
  else
    break
  end
end