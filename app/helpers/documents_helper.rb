module DocumentsHelper  
  #def select_for_itype(default)
  #  options = ['all','calendar','file','email','webpage','news','blog','concept'] #'paper',
  #  select_tag(:itype, options_for_select(options.map{|e|[e,e]},default), 
  #    :multiple=>true, :onchange => 'this.form.submit()')
  #end
  
  def user_level()
    session ? session[:user_level].to_i : 0
  end
  
  def user_level_new(score)
    if score >= 75 : 2
    elsif score >= 50 : 1
    else
      0
    end
  end
  
  def apply_user_level
    return if @user_level_applied
    @queries_per_page -= user_level * 2
    @no_entry_concept -= user_level * 2
    @display_page_total += user_level
    @user_level_applied = true
  end
  
  def update_user_level(score)
    session[:user_level] = user_level_new(score)
    User.find(session[:user_id]).update_attributes!(:level=>user_level_new(score))
  end
  
  def display_user_list(level)
    User.find_all_by_level(level).map{|e|(e.id == session[:user_id])? "<b>#{e.uid}</b>" : e.uid}.join(" ")
  end
  
  def display_game_type()
    case session[:game_type]
    when :s : "Searching"
    when :sb : "Searching+Browsing"
    when :b : "Browsing"      
    end
  end
  
  def display_url(item)
    case item.uri
    when /\.(#{FileCollector::FILE_FORMAT_BINARY})$/
      "http://docs.google.com/viewer?url=#{url_encode(item.uri.strip)}&embedded=true"
    when /^http/
      if item.uri =~ /wikipedia/
        item.uri + "?printable=true"
      elsif item.itype == 'blog'
        url_for :action=>:show_content, :id=>item.id
      else
        item.uri
      end
    else
      url_for :action=>:show_content, :id=>item.id
    end
  end
  
  # Display link URL for clickthrough recording
  def display_link(item, rank_list, htype, position)
    if during_game?
      if session[:game_type] != :s && !page_found? && !query_limit_reached?
        link_to item.title, {:action=>'click', :htype=>htype, :id=>item.id, :src_item_id=>session[:target_document], 
          :position=>(position+1), :skipped_items=>rank_list[0..position].reverse.join("|")}, :title=>'Click to see more items like this!'
      else
        item.title
      end
    else
      link_to item.title, {:action=>'show', :id=>item.id}
    end
  end
  
  def redirect_to_after(url , second)
    "<meta http-equiv='refresh' content='#{second};url=#{url}'>"
  end
    
  # Initialize per-game variable
  def init_game(game_id)
    session[:game_id] = game_id
    session[:total_query_count] = 0 # #queries in overall
    session[:seen_doc_count] = 0
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
    #session[:refresh_count] = 3
    session[:display_page_cur] = 0
    
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
