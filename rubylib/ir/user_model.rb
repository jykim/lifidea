# == Probabilistic User Model
#  
# - Generate the sequence of user interaction given the parameter and the collection
# 
# == Input
# - IR::Index
#
# == Output
# - Query instances
# - History instance
class UserModel
  def initialize()
    @user_id = 2
    @session_length = 5
    @game_id = nil
    @ss = SolrSearcher.new
  end
  
  #
  def run(target_items)
    target_items.each do |item|
      hist = gen_query(item)
      next if !hist
      puts "== ITEM #{item.id} =="
      0.upto(@session_length) do |i|
        if !hist.m[:rank] || hist.m[:rank] < 10 || !hist.item
          break
        end
        puts "[UserModel#run] item found at #{hist.m[:rank]} by #{i}th click!"
        hist = gen_click(hist.item, :src_item_id=>item.id)
      end
    end
  end
  
  def get_search_type(itype)
    (Item::ITYPE_CONCEPT.include?(itype))? 'con' : 'doc'
  end
  
  #
  def get_search_rank(search_result, item_id)
    result = search_result.find{|r|r[:id] == item_id}
    result ? result[:rank] : nil
  end
  
  # Generate query log
  # - choose click position 
  # - create history record 
  def gen_query(item, qtype = :document, o = {})
    o[:length] ||= 3
    case qtype
    when :document
      begin
        query = item.get_index().lm.p.sample_pdist(o[:length]).join(' ')
      rescue Exception => e
        error "Error in query generation", e
        return nil
      end      
    end
    search_result = @ss.search_by_keyword(query, :doc_only=>true, :page=>1, :per_page=>100)
    return nil if !search_result || !search_result[0]
    tgt_item = choose_position(search_result, item.id)
    History.create(:htype=>'query', :basetime=>Time.now, :item_id=>tgt_item, :src_item_id=>item.id, :user_id=>@user_id,
      :game_id=>@game_id, :metadata=>{:query=>query, :rank=>get_search_rank(search_result, item.id)})
  end
  
  # Generate click log
  # - choose position
  def gen_click(item, o={})
    search_result = @ss.search_by_item(item.id, get_search_type(item.itype) , :content_only=>true)
    #p search_result
    tgt_item = choose_position(search_result, item.id)
    History.create(:htype=>get_search_type(item.itype), :basetime=>Time.now, :src_item_id=>item.id, :item_id=>tgt_item, :user_id=>@user_id,
      :game_id=>@game_id, :metadata=>{:real_src_item_id=>o[:src_item_id] ,:rank=>get_search_rank(search_result, o[:src_item_id])})
  end
  
  def choose_position(search_result, item_id)
    p search_result
    item_rank = search_result.map{|e| 
      search_result_new = @ss.search_by_item(e[:id], 'doc')
      [e[:id], get_search_rank(search_result_new, item_id)] }.find_all{|e|e[1]}
    info "[choose_position] #{item_rank.inspect}"
    return nil if item_rank.size == 0
    item_rank.sort_by{|e|e[1]}[0][0]
  end
end