require 'ddl_include'
require 'ruby-prof'
  
col = file_load("col_test.dmp")
#col = IR::Index.create_from_yaml(IO.read("col_test.yaml"))

searcher = Searcher.new(col, Searcher::RULE_DEF)
queries = IO.read(PATH_COL+"c0002_lists_manual_PRM-S.qry").find_tag("query").map{|e|e.gsub("combine ","combine").gsub(/\s\s+/,"").gsub("\n"," ")}
results = []
RubyProf.start
queries[0].each_with_index do |query,i|
  #debugger
  puts "Query[#{i}] : [#{query}]"
  results[i] = searcher.search(query, :docs=>ARGV)
  puts results[i][0..10].map{|e|e.join("\t")}.join("\n")
end
result = RubyProf.stop

# Print a flat profile to text
printer = RubyProf::GraphPrinter.new(result)
printer.print(STDOUT, 0)