class ContextVector
  def initialize()
    unless get()
      clear()
    end
  end
  
  def get()
    cache_data('context')
  end
  
  def add(arg)
    context = get()
    return if context.size > 0 && (arg[:title] == context.last[:title])
    cache_data('context', context << arg )
  end
  
  def clear()
    cache_data('context', [] )
  end
end