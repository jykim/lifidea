# Model Feature of Links
class LinkFeatures
  attr_reader :v
  
  def initialize()
    @v = {}
  end
  
  # Load from Link Records
  # @param [Array<[ltype, out_id, in_id, weight]>]
  # - o[:force] : ignore consistency checking for output
  # - constraint : in_id should be bigger than out_id (otherwise, it's skipped)
  def load(links, o = {})
    i = 0.0
    links.each do |l|
      if l[1] >= l[2] && !o[:force]
        info "Inconsistent Input #{l.inspect}, skipping..." if l[0] != 'e'
        next
      end
      v[l[0]] = {} if !v[l[0]]
      v[l[0]][l[1]] = {} if !v[l[0]][l[1]]
      v[l[0]][l[2]] = {} if !v[l[0]][l[2]]
      v[l[0]][l[2]][l[1]] = l[3].to_f
      v[l[0]][l[1]][l[2]] = l[3].to_f
      i += 1
    end
    #debug "[LinkFeatures::load] #{i} links loaded"
  end
  
  def read(ltype, out_id, in_id)
    in_id, out_id = out_id, in_id if out_id > in_id
    return 0.0 if !v[ltype]
    return 0.0 if !v[ltype][in_id]
    #debug "[LinkFeatures::load] v[#{ltype}][#{in_id}][#{out_id}] = #{v[ltype][in_id][out_id]}"
    v[ltype][in_id][out_id] || 0.0
  end
  
  def read_sum(ltype, id)
    read_links(ltype, id).values.sum.to_f
  end
  
  # Read the links associated with given item
  # @param ltype <Char>
  # @param id <Int>
  def read_links(ltype, id)
    return {} if !v[ltype]
    return {} if !v[ltype][id]
    v[ltype][id]
  end
  
  def increment(ltype, out_id, in_id)
    in_id, out_id = out_id, in_id if out_id > in_id
    #debug "[LinkFeatures::increment] v[#{ltype}][#{in_id}][#{out_id}]+1"
    load([[ltype, in_id, out_id, 1]])
  end
end