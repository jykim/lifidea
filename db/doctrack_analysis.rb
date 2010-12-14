#load 'rubylib_include.rb'
#require 'time'
#require 'FasterCSV'
#require 'yaml'

def conv_itype(itype)
  case itype
  when 'concept' : itype
  when 'query_doctrack' : 'query'
  else 'document'
  end
end

def import_click_position()
  #hist_pos = []
  hist_pos = {}
  History.all.group_by{|e|[e[:game_id],e[:src_item_id],e[:item_id]].join('_')}.each {|rid, rows|
    positions = rows.map{|r|r[:metadata][:position]}.uniq
    #p rid, positions if positions.size > 1
    hist_pos[rid] = positions#.join('_')
    #hist_pos <<  [rid, positions.join('_')]
  } ; nil
  hist_pos
  #write_csv('hist_pos', hist_pos, :header=>[:rid, :positions] )
end

$cp = import_click_position()#read_csv('hist_pos').map_hash{|e|[e[:rid], e[:positions].split('_')]}
$ss = SolrSearcher.new
def get_click_position(rid, rtype, prev_query)
  position = $cp[rid]
  if position && position.size != 0
    $cp[rid] = position[1..-1]
    puts "    [get_click_position] position : #{position[0]}"
    return position[0]
  end
  query = Item.find(prev_query)
  if rtype == 's_to_b'
    #debugger
    result = $ss.search_by_keyword(query.title).find{|e|e[:id] == rid.split('_')[2].to_i}
    if result
      puts "    [get_click_position] query: #{query.title} -> item: #{result.inspect}"
      return result[:rank]
    end
  end
  nil
end

row_count = 0
time_by_itype = []
dt = read_csv('data/dt2_sessions')
dt.group_by{|e|[e[:game_id], e[:k1]].join('_')}.each do |sid, rows|
  rows = rows.sort_by{|e|e[:id].to_i}
  rf, rl = rows[0], rows[-1]
  itypes = rows.map{|e|e[:t2]}
  next if ['jykim', 'abakalov'].include?(rf[:uid]) || rf[:t1] == 'concept' || 
          !itypes.include?('query_doctrack') || rows.size < 2# rf[:position].to_i < 0 ||
  puts "----- #{rf[:t1]}::#{rf[:i1]} (#{sid}) -----"
  rows.each_with_index do |r, i|
    if i > 0 && r[:created_at]
      rp = rows[i-1]
      time_spent = Time.parse(r[:created_at]) - Time.parse(rp[:created_at])
      rtype = if rp[:t2] == 'query_doctrack' && r[:t2] != 'query_doctrack'
        's_to_b'
      elsif rp[:t2] != 'query_doctrack' && r[:t2] == 'query_doctrack'
        'b_to_s'
      elsif rp[:t2] == 'query_doctrack' && r[:t2] == 'query_doctrack'
        'search'
      else
        'browse'
      end
      cpos = get_click_position([sid, r[:k2]].join('_'), rtype, rp[:k2])
      puts "  #{rtype}\t#{time_spent}\t#{r[:position]}\t#{cpos}\t#{r[:t2]}::#{r[:i2]}" 
      time_by_itype << [rtype, conv_itype(r[:t2]), time_spent, r[:position].to_i, cpos.to_i]
    end
  end
  row_count += 1
end
puts "Total : #{row_count} rows"
puts "[time by itype]"
time_by_itype.group_by{|e|e[1]}.each{|k,v|puts "  #{k}\t#{v.size}\t#{v.map{|e|e[2]}.mean}"}
puts "[%failure by rtype]"
time_by_itype.group_by{|e|e[0]}.each{|k,v|puts "  #{k}\t#{v.size}\t#{v.find_all{|e|e[3]==-1}.size / v.size.to_f}"}
write_csv "time_by_itype", time_by_itype, :header=>[:rtype, :itype, :time, :rpos, :cpos]
