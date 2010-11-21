module MarkupHelper
  PTN_MARKUP = /\{(.+?)\}/
  PTN_ELEMENT_SEP = /\s*\,\s*/
  PTN_METADATA = /(\w+)\s*:\s*(\S+)/
  # Extract tag & metadata from markup
  def process_markup()
    [title,content].each do |text|
      next if !text
      clear_webpage(text).scan(PTN_MARKUP).map{|e|e[0].split(PTN_ELEMENT_SEP)}.flatten.each do |element|
        #debug "[process_markup] element: "+element.inspect
        next if !element
        ptn = element.scan(PTN_METADATA)
        #debug "[process_markup] ptn: "+ptn.inspect
        if ptn.size > 0
          m[ptn[0][0].to_sym] = parse_value(ptn[0][1])
        else
          create_and_link(element, 'tag' , "t")
          #add_tags(element, "m")
        end
      end#scan
    end#each
  end
end