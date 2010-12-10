# Store Searcher Context for Improving Suggestions
# 
class ContextVector
  SESSION_DURATION = 300
  
  def initialize()
    unless get()
      clear()
    end
  end
  
  def print(history_id = nil)
    get(history_id).each{|e|e2 = e.dup ; e2.delete(:result) ;  e2.delete(:query) ; puts e2.map{|k,v|"#{k} : #{v}"}.join("\t")}
    nil
  end
  
  def clear()
    cache_data('context', [] )
    cache_data('session_id', 0)
  end
    
  def next_session_id()
    cache_data 'session_id',  cache_data('session_id') + 1
  end
  
  def get_session_id()
    cache_data('session_id')
  end
  
  # Get part or all of context vector
  def get(history_id = nil, htype = nil)
    context = cache_data('context')
    if history_id
      cur_entry = context.find{|e|e[:history_id] == history_id}
      return nil if !cur_entry
      debug "[ContextVector#get] cur_entry = #{cur_entry[:id]}"
      context[0..cur_entry[:id]].
        find_all{|e|e[:session_id] == cur_entry[:session_id] && (e[:htype] == 'kwd'|| e[:htype] == htype) }
    else
      context
    end
  end
  
  # Add new entry to session
  # - avoid duplicate entry
  # - move into the new session when the duration exceeded
  def add(arg)
    context = get()
    #debug "[ContextVector#add] [#{arg[:query]}] to [#{context.last[:query]}]" if context.last
    return nil if context.size > 0 && (arg[:query] == context.last[:query])
    session_id = if context.size > 0 && arg[:created_at] - context.last[:created_at] > SESSION_DURATION
      next_session_id()
    else
      get_session_id()
    end
    cache_data('context', context << arg.merge(:id=>context.size, :session_id=>session_id) )
  end
end