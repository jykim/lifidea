
class ConceptExtractor
  PTN_EMAIL = /([\w \-]+?) \<(.*)\>/ # $1 : name , $2 : email
  
  def initialize()
    initialize_dict()
  end
  
  def self.choose_type_by_title(title)
    words = title.split(" ") 
    return "org" if words.size < 2 || words.size > 3
    #return "org" if words.find_all{|e|$dict.key?(e.downcase)}.size > 0
    'person'
  end
  
  def process_email(doc, str)
    if PTN_EMAIL =~ str
      title, email = $1.strip, $2
      ctype = ConceptExtractor.choose_type_by_title(title)
      begin
        con = Concept.find_or_create(title, :ctype=>ctype, :email=>email)
        Occurrence.find_or_create(doc.id, con.id, "s")
        con
      rescue Exception => e
        #debugger
        error "[process_email] error in #{str}", e
      end      
    else
      nil
    end
  end
  
  # Extract seed concept from email sender/receiver (@deprecated)
  # - extract ConceptLink from each sender-receiver
  def extract_people_from_email(docs)
    docs.each do |d|
      puts "Processing #{d.title}"
      sender = process_email(d, d.m[:from]) if d.m[:from]
      receivers = d.m[:to].split(",").map{|e|process_email(d,e)}.find_all{|e|e} if d.m[:to]
      next if !sender || !receivers || receivers.size < 1
      receivers.each do |r|
        ConceptLink.find_or_create(sender.id, r.id, 's')
      end
    end
  end
  
  # Extract person/event occurrence from calendar (@deprecated)
  # - weight determined by cosine similarity
  def extract_from(docs)
    concepts = Concept.all(:conditions=>["(ctype=? or ctype=?) and judgment != 0", "person","event"])
    col = IR::Index.new( [docs, concepts].flatten.map{|d|d.index}, :init_df=>true)
    docs.each do |d|
      #debug "[extract_from_calendar] document: #{d}"
      concepts.each do |c|
        weight = d.index.cosim(c.index) #d.index.lm.f.cosim(c[1].f)
        #Occurrence.find_or_create(d, c, weight) if weight > 0
      end
    end
  end
end
