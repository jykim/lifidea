require 'socket'      # Sockets are in standard library
if ARGV.size == 2
  host = ARGV[0]
  port = ARGV[1]

  s = TCPSocket.open(host, port.to_i)
  s.puts "Hello"
  while line = s.gets   # Read lines from the socket
    puts line.chop      # And print with platform line terminator
  end
  s.close               # Close the socket when done
else
  server = TCPServer.open(ARGV[0].to_i)  # Socket to listen on port 2000
  loop {                         # Servers run forever
    client = server.accept       # Wait for a client to connect
    puts "[client]"+client.gets
    client.puts(Time.now.ctime)  # Send the time to the client
    client.puts "Closing the connection. Bye!"
    client.close                 # Disconnect from the client
  }
end