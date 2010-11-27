module ItemsHelper
  def select_for_itype(default)
    #options = case type
    #when 'Document' : ['webpage','email','pub','file']
    #when 'Concept' : ['person','concept']
    #when 'Query' : ['web','local']
		#end
    #select_tag(:itype, options_for_select(options.map{|e|[e,e]},default), 
    #  :multiple=>true, :onchange => 'this.form.submit()')
    options = ['all','webpage','email','pub','memo','news','blog','file','concept','query']
    select_tag(:itype, options_for_select(options.map{|e|[e,e]},default), 
      :multiple=>true, :onchange => 'this.form.submit()')
  end
  
  def select_for_facet(params, param_name, options)
    select_tag(param_name, options_with_all(params[param_name], options), :onchange => 'this.form.submit()')
  end
  
  def options_with_all(param, options)
    options_for_select([['all',-1]].concat(options),param ? param.map{|e|e} : [-1])
  end
  
  def search_local(qtype, query, o={})
    $searcher = SolrSearcher.new
    @rank_list = $searcher.process_request(qtype, query, o)
  end
end
