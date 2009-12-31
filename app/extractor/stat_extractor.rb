
class StatExtractor
  def initialize()
    #@tag_prefix ||= get_config("TAG_PREFIX_RULE")
  end
  
  # Return the beginning of period including the basedate
  def period_start_at(basedate, unit)
    basedate = Time.parse(basedate) if basedate.class.to_s == "String"
    basedate.send("beginning_of_"+unit) + SysConfig.hour_daybreak    
  end
  
  def period_end_at(basedate, unit)
    basedate = Time.parse(basedate) if basedate.class.to_s == "String"
    basedate.send("beginning_of_"+unit).send("next_"+unit) + SysConfig.hour_daybreak
  end

  # Select target documents that falls within given period & condition
  #  - select documents from the start and end of period given basedate
  # @param <String> basedate "YYYYMMDD"
  # @param <Symbol> unit of period :day, :week, :month
  def select_docs_by(basedate, unit, itype, condition)
    #SQL filter by date & itype
    start_at = period_start_at(basedate, unit).in_time_zone
    end_at = period_end_at(basedate, unit).in_time_zone
    #debugger
    #debug("#{start_at} ~ #{end_at}")
    itypes = (itype == "all")? Item.itype_lists : itype.to_a
    cond = ["basetime >= ? and basetime< ? and itype in (?)", start_at, end_at, itypes]
    
    #Fetch either from Document or DataDocument
    docs = Item.all(:conditions=>cond).group_by(&:itype)
    result = {}
    docs.each do |itype,docs|
      #info("[StatExtractor:select_docs_by(#{start_at.ymdhms} ~ #{end_at.ymdhms}}/#{itype})] total #{docs.size} docs")
      docs = docs.find_all do |d|
        d.validate_by_condition(condition)
      end#find
      if block_given?
        yield itype, docs
      else
        result[itype] = docs
      end
    end#each(itype)
    result
  end

  #
  def extract_stat(basedate, unit, rtype, r = {})
    #info "[RuleExtractor:extract_stat] Processing #{r[:rid]} @ #{basedate}/#{unit}"
    select_docs_by(basedate, unit, r[:itype], r[:condition]) do |itype, docs|    
      sid = "#{r[:rid]}_#{unit}_#{basedate}"
      target = r[:target].to_sym if rtype != "count"
      next if docs.size == 0
      content = case rtype
      when "count"
        docs.size
      when "sum"
        docs.map{|d|d.text_in(target)}.sum
      when "avg"
        docs.map{|d|d.text_in(target).to_f}.avg.r3
      when "stdev"
        docs.map{|d|d.text_in(target).to_f}.stdev.r3
      when "min"
        docs.map{|d|d.text_in(target)}.min
      when "max"
        docs.map{|d|d.text_in(target)}.max
      end
      stat = Stat.find_or_initialize_by_sid(sid)
      stat.update_attributes(:rid=>r[:rid], :unit=>unit, :content=>content, 
        :stype=>rtype, :source=>r[:itype], :doc_count=>docs.size, :basedate=>basedate)    
    end
  end
end
