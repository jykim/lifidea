module ItemsHelper
  def select_for_itype(default)
    #options = case type
    #when 'Document' : ['webpage','email','pub','file']
    #when 'Concept' : ['person','concept']
    #when 'Query' : ['web','local']
		#end
    #select_tag(:itype, options_for_select(options.map{|e|[e,e]},default), 
    #  :multiple=>true, :onchange => 'this.form.submit()')
    options = ['all','webpage','email','pub','memo','file','concept','query']
    select_tag(:itype, options_for_select(options.map{|e|[e,e]},default), 
      :multiple=>true, :onchange => 'this.form.submit()')
  end
end
