module RuleHelper  
  # Extract tag from rules
  def process_rules(rules)
    rules.sort_by{|r|r.rid}.each do |r|
      #debug "[process_rules] Applying #{r.rid}"
      if r.match_itype(itype) && validate_by_condition(r[:condition])
        if r[:target]
          text_in(r[:target]) =~ /#{r[:value]}/
          r[:value] = $1
        end
        #debugger
        #info "[process_rules] Tag #{r[:value]} applied"
        add_tags(r[:value], "r")
        save!
        #debug "[concepts.size] #{concepts.size} / #{occurrences.size}"
      end
    end
  end
  
  # Extract text from target field
  def text_in(target)
    raise ArgumentError if target.class != Symbol
    if target == :tag
      #debug "[text_in] concept_titles : #{concept_titles.join(",")}"
      tag_titles.join(",")
    elsif Item.col_lists.include?(target.to_s)
      send(target.to_s)
    else
      m.send("[]",target.to_sym)
    end
  end
  
  # Validate document by user-defined condition
  # - used for collection / tagging / statistics
  def validate_by_condition(condition)
    return true if !condition
    raise ArgumentError if condition.class != Hash
    result = true
    condition.each do |target, value|
      value = parse_value(value)
      text = text_in(target)
      #debug "#{concept_titles} / [#{text}] <-> #{value}" if target == :tag
      #debugger if /scored/ =~ value.to_s
      result = case value.class.to_s
      when "Array" : value.include?(text)
      when "Range" : value === text
      when "Regexp" : text =~ value
      when "String" : value == text
      when "Symbol" : value == text
      when "NilClass" : text # checking the existence of metadata field
      else
        error("[validate_by_condition] Unidentifiable condition #{condition.inspect}");false
      end
      return false if !result
    end
    result
  end
end