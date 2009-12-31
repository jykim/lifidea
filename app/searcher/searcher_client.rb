require 'ddl_include'
require "socket"

def get_searcher_port()
  #return $searcher_port if $searcher_port
  port = get_config("PORT_SEARCHER").to_i
  $searcher_port = case ENV['RAILS_ENV']
  when 'production'
    port + 2
  when 'test'
    port + 1
  else
    port
  end
end

# Send request to remote(local) search server
# @param[String] qtype : type of query
def search_remote(qtype, query, o={})
  port = o[:port] || $searcher_port || get_searcher_port()
  jtype = o[:jtype] || 'search'
  puts "port = #{port}"
  host = "localhost" || o[:host]

  session = TCPSocket.new(host, port)
  puts YAML.dump(:jtype=>jtype, :qtype=>qtype, :query=>query)
  session.puts YAML.dump(:jtype=>jtype, :qtype=>qtype, :query=>query)
  result = receive_yaml(session)
  session.close
  result
end

# Receive packet request in YML format
def receive_yaml(session, o = {})
  result = [] ; lines = 0
  while (line = session.gets)
    result << line
    puts line.inspect
    lines += 1
    break if o[:max_lines] && lines >= o[:max_lines]
  end
  YAML.load(result.join(""))  
end
