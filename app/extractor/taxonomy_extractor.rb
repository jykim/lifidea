class TaxonomyExtractor
  def initialize
    @support = 10
    @solr = SolrSearcher.new
  end
  
  def extract()
    #allterms = Item.concepts.valid.map{|e|e.title}#
    allterms = Item.itype(['concept']).map{|e|e.title}#
    genTFIT([], [], allterms)
  end
  
  def genTFIT(tplus, tminus, allterms, prevterm = nil, relation = nil, l = 0, w = 0)
    splus = tplus.map{|e|"+\"#{e}\""}.join(" ")
    sminus = tminus.map{|e|"-\"#{e}\""}.join(" ")#
    tnext, fnext = *allterms.map{|e| [e, @solr.calc_df("\"#{e}\" #{splus} #{sminus}")]}.sort_by{|e|e[1]}[-1]
    
    if( fnext >= @support)
      puts "#{l} / #{w} / \"#{prevterm}\" / \"#{tnext}\" / [label=\"#{relation}\"] / #{fnext} /" + 
           "/ PLUS : #{tplus.join(',')} / MINUS : #{tminus.join(',')}"
      allterms.delete(tnext)
      genTFIT([tplus, tnext].flatten, tminus, allterms, tnext, 'anc', l+1, w)
      genTFIT(tplus, [tminus, tnext].flatten, allterms, tnext, 'prd', l, w+1)
    end
  end
end