module MetadataHelper
  def validate_metadata
    raise DataError, "Invalid metadata #{metadata.inspect}" if metadata.class.to_s != "Hash"
    raise DataError, "Invalid textindex #{textindex.inspect}" if metadata.class.to_s != "Hash"
  end
  
  # Extract different metadata for each item type
  def process_metadata()
    m.merge!(:type=>itype)
    result = case itype
    when 'calendar'
      calendar_metadata_handler
    #when 'todo'
    #  todo_metadata_handler
    when 'email'
      email_metadata_handler
    else
      {}
    end
  end
  
  def calendar_metadata_handler()
    result = if content =~ /^When: (.*) (.*) to (.*)/
      {:type=>:hourly, :start_at => Time.parse($1+" "+$2), :end_at =>Time.parse($1+" "+$3)}
    elsif content =~ /^When: (.*)\<br/
      {:type=>:allday, :start_at => Time.parse($1), :end_at => Time.parse($1)}
    else
      {:start_at=>basetime.to_time.to_s(:rfc822)}
      #error "[calendar_metadata_handler] Unrecognized content format #{content}"
    end
    #if result[:start_at]
    #  result[:end_at] += 86400 if result[:start_at] != result[:end_at] && result[:end_at].hour == 0
    #  result.merge!(:hour_plan=>((result[:start_at] - date_published)/3600).round_with_precision(1), 
    #    :hour_do=>(result[:end_at]-result[:start_at])/3600, :published_at=>date_published)
    #end
    # LESSON : using basetime= setter doesn't change field value reliably
    write_attribute(:basetime, result[:start_at])
    #puts "basetime = #{basetime}" if itype == 'calendar'
    #debugger
    m.merge!(result)
  end
  
  def todo_metadata_handler()
    if m[:completed_at] 
      m.merge!(:duration=>(m[:completed_at] - basetime))
    end
  end
  
  def email_metadata_handler()
    #debugger
    #metadata = metadata.find_all{|k,v|[:from,:date,:to].include?(k)}.map_hash{|e|[e[0].to_sym,e[1]]}
  end
end
