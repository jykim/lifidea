require File.dirname(__FILE__) + "/../../lib/daemon_include.rb"
require 'socket'                # Get sockets from stdlib
#info "[searcher_daemon] initializing... (port=#{port})"
#debugger
$searcher = Searcher.new(Searcher::RULE_DEF)
$searcher.load_documents()

#$last_query_no = get_config('LAST_QUERY_NO').to_i
#$searcher.load_concepts()
#$basedate = Time.now.to_ymd
#$weights = Searcher.load_weights()
#$f_li = File.open(RAILS_ROOT+"/data/learner_input/learner_input_#{ENV['RAILS_ENV']}_#{$basedate}.txt", 'a')
#puts "Weights Read : #{$weights.inspect} / LAST_QUERY_NO = #{$last_query_no}"  

if $profile
  require 'ruby-prof'
  cons = Item.valid.indexed.concepts
  RubyProf.start
  1.upto(ENV['repeat'].to_i||10) do |i|
    puts "#{i}th concept : #{cons[i]}"
    $searcher.cons.find_similar(cons[i].id, :weights=>$weights)
  end
  result = RubyProf.stop
  printer = RubyProf::FlatPrinter.new(result)
  printer.print(STDOUT, 0)
  exit()
end

begin
  server = TCPServer.open(Conf.searcher_port)  
rescue Exception => e
  errror "Failed to open socket!", e
end
puts "Ready to accept client at #{Conf.searcher_port}"
while($running) do
  #Thread.start(server.accept) do |client|
    client = server.accept
    info "[searcher_daemon] Accepted!"
    #debugger
    request = receive_yaml(client, :max_lines=>4)
    info "[searcher_daemon] Request : #{request.inspect}"
    begin
      result = case request[:jtype]
      when 'search'
        case request[:qtype]
        when 'k' : $searcher.search_by_keyword(request[:query])
        when 'c' : $searcher.cons.find_similar(request[:query].to_i, :weights=>$weights)
        end
      when 'log'
        case request[:qtype]
        when 'c' : $searcher.cons.log_preference(request[:query])
        end
      end
      #puts YAML.dump(result)
      client.puts YAML.dump(result)
      info "[searcher_daemon] response sent!"
      sleep(0.1)
    rescue Exception => e
      error "[searcher_daemon] Unhandled exception!", e
    end
    client.close                # Disconnect from the client
  #end
end
info "[searcher_daemon] Quitting!"
