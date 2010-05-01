module DocumentsHelper  
  #def select_for_itype(default)
  #  options = ['all','calendar','file','email','webpage','news','blog','concept'] #'paper',
  #  select_tag(:itype, options_for_select(options.map{|e|[e,e]},default), 
  #    :multiple=>true, :onchange => 'this.form.submit()')
  #end
  
  def display_url(item)
    case item.uri
    when /\.(#{FileCollector::FILE_FORMAT_BINARY})$/
      "http://docs.google.com/viewer?url=#{url_encode(item.uri.strip)}&embedded=true"
    when /^http/
      if item.uri =~ /wikipedia/
        item.uri + "?printable=true"
      elsif item.source.o[:show_url]
        item.uri
      else
        url_for :action=>:show_content, :id=>item.id
      end
    else
      url_for :action=>:show_content, :id=>item.id
    end
  end
  
  def display_link(item)
    if session[:game_type] == :sb
      link_to item.title, {:controller=>'documents', :action=>'click', :htype=>'qry_doc', :id=>item.id, :src_item_id=>@query_doc.id}
    else
      item.title
    end
  end
  
  def redirect_to_after(url , second)
    "<meta http-equiv='refresh' content='#{second};url=#{url}'>"
  end
    
  # Initialize per-game variable
  def init_game(game_id)
    session[:game_id] = game_id
    session[:total_query_count] = 0 # #queries in overall
    session[:seen_doc_count] = -1
    session[:score] = 0
    session[:query_count] = 0
    session[:display_page_cur] = 0
    #init_target_document()
  end
  
  def finish_game()
    session[:game_id] = nil
  end
  
  # Initialize per-document variable
  def init_target_document()
    session[:query_count] = 0
    session[:display_page_cur] = 0
    session[:seen_doc_count] += 1
    
    session[:display_docs] = []
    session[:document_index] = nil
    
    session[:game_type] = @ratio_game_type.dice[0]
  end
  
  def during_game?
    session[:game_id]
  end
  
  def page_found?
    puts "#@relevant_position <= #@display_topk_result"
    @relevant_position <= @display_topk_result && @relevant_position > 0
  end
  
  def query_limit_reached?
    during_game? && session[:query_count] >= @queries_per_page
  end
  
  def game_finished?
    session[:seen_doc_count] && session[:seen_doc_count] >= @pages_per_game
  end
  
  def source_given?
    params && params[:source]
  end
end
