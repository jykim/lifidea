class SolrSearcher < Searcher
  attr_accessor :items
  def initialize(o={})
    super(o)
    nil
  end
  
  def open_index(o={})
    super(o)
  end
  
  # Search given keyword query
  def search_by_keyword(query, o={})
    #debugger
    #debug "[search_by_keyword] query = #{query}"
    result = Sunspot.search(Item) do
      keywords query
      if o[:doc_only]
        without :itype_str, ['query','concept','tag']
      end
      #debugger
      o.find_all{|k,v|k.to_s =~ /^facet\_/}.each do |e|
        #debugger
        with (e[0].to_s.split('_')[1..-1].join('_')).to_sym, e[1] if [e[1]].flatten.first != '-1'
      end
      #debugger
      order_by(:basetime, :desc) if o[:order] == "recency" || query == TEXT_DUMMY
      paginate(:page => o[:page]) if o[:page]
      facet(o[:facet]) if o[:facet]
      without :hidden_flag, '1'
    end
    #debugger
    if o[:facet]
      result.facet(o[:facet]).rows
    elsif o[:raw]
      result
    else
      result_items = result.hits.map{|e|{:id=>e.instance.id, :score=>e.score}}
      @cv.add(:type=>'kwd', :query=>query, :created_at=>(o[:created_at] || Time.now), :history_id=>o[:history_id], :result=>result_items) if o[:add_context]
      result_items
    end
  end
  
  # 
  def calc_df(query, tplus = [], tminus = [])
    #debugger
    splus = tplus.map{|e|"+'#{e}'"}.join(" ")
    sminus = tminus.map{|e|"-'#{e}'"}.join(" ")#
    query = "'#{query}' #{splus} #{sminus}"
    result = Sunspot.search(Item) do
      keywords query
      without :itype_str, Item::ITYPE_CONCEPT
      #tplus.each{|e| with :fulltext, "\"#{e}\""} if tplus
      #tminus.each{|e| without :fulltext, "\"#{e}\""} if tminus
    end
    #debug "[calc_df] #{query} : #{result.total}"
    result.total
  end
  
  # Filter itype from solr search results
  def solr_filter_concepts(prefix = '+', join = ' || ')
    ['query'].map{|e|"#{prefix}itype_text:#{e}"}.join("#{join}")
  end
  
  # Get similarity search result from Solr
  # - cache item fetched from database
  def solr_search_by_item(query_item, type, o={})
    # Filter query results
    if o[:working_set]
      filter_qry = o[:working_set].map{|e|"id_text:#{e}"}.join(" || ") 
    else
      case type
      when 'con' : filter_qry = solr_filter_concepts()
      when 'doc' : filter_qry = solr_filter_concepts('-', '&&')
      end
    end
    
    #debugger
    # Initial Solr Query
    solr = RSolr.connect :url=>Conf.solr_server
    begin
      solr_result = solr.request "/mlt", :q => "id:\"Item #{query_item.id}\"",:fl => "*,score", :fq =>filter_qry , "rows" => (o[:rows] || 50), 
        "mlt.fl" => "title_text,content_text,metadata_text,uri_text,itype_text", "mlt.mintf" => 1, "mlt.mindf" => 5, "mlt.boost"=>true
        
      # Cache results returned
      Item.find(solr_result['response']['docs'].map{|e|e["id"].split(" ")[1]}).
        each{|i| $items[i.id] = cache_data("item_#{i.id}", i)}  
    rescue Exception => e
      error "[search_by_item] Error in Calling Solr", e
      return []
    end
    info "[search_by_item] Nothing returned from Solr!!!" if solr_result['response']['docs'].size == 0
    # Feature Vector generation
    solr_result['response']['docs']
  end
end
