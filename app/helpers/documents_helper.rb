module DocumentsHelper
  
  # Create concepts & occurrences
  # @param otype [String] type of occurrences
  def add_concepts(titles, otype, o={})
    #debug "[add_concepts] titles = [#{titles}] otype = #{otype} (#{@concept_titles})"
    titles = titles.split(",").find_all{|e|!e.blank?} if titles.class == String
    #debugger
    concepts = titles.map{|t|Concept.find_or_create(t.strip, :ctype=>o[:ctype])}
    concepts.each{|c|Occurrence.find_or_create(self.did, c.cid, otype, o[:weight])}
    #@concept_titles = concept_titles | titles
    #update_attributes!(:concept_titles=>@concept_titles)
  end
  
  def select_for_itype(default)
    options = ['all','calendar','file','email','webpage','news','blog'] #'paper',
    select_tag(:itype, options_for_select(options.map{|e|[e,e]},default), 
      :multiple=>true, :onchange => 'this.form.submit()')
  end
  
  def display_url(item)
    case item.uri
    when /\.(#{FileCollector::FILE_FORMAT_BINARY})$/
      "http://docs.google.com/viewer?url=#{url_encode(item.uri.strip)}&embedded=true"
    when /^http/
      if item.url =~ /wikipedia/
        item.uri + "?printable=true"
      else
        item.uri
      end
    else
      url_for :action=>:show_content, :id=>@item.id
    end
  end
  
  def redirect_to_after(url , second)
    "<meta http-equiv='refresh' content='#{second};url=#{url}'>"
  end
  #<% if params[:random] && @display_page_total <= session[:display_page_cur] %>
  #	<%= redirect_to_after(url_for(:action=>:start_search), @time_per_page)  %>
  #<% elsif params[:random] %>
  #	<%= redirect_to_after(url_for(:action=>:show, :random=>true), @time_per_page)   %>
  #<% end %>
  
  def during_game?
    session[:query_count]
  end
  
  def page_found?
    @relevant_position <= @display_topk_result && @relevant_position > 0
  end
  
  def query_limit_reached?
    during_game? && session[:query_count] >= @queries_per_page
  end
  
  def game_finished?
    session[:seen_doc_count] && session[:seen_doc_count] >= @pages_per_game
  end
end
