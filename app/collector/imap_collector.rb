require 'ddl_include'
require 'net/imap'
require 'net/http'

# Collect from IMAP Mailbox
class IMAPCollector < Collector

  # Fetch email by IMAP
  # - use Source#sync_at to determine from when the fetch should begin
  # @option o [Int] :port server port .no
  # @option o [String] :id server id
  # @option o [String] :password server password
  # @option o [String] :id folder IMAP mailbox name (also, gmail label)
  def read_from_source(o = {})
    @imap = Net::IMAP.new(@src.uri.gsub("imap://",""), @src.o[:port] , true)
    @imap.login(@src.o[:id], @src.o[:password])
    @imap.examine(@src.o[:folder])
    result = []
    
    @imap.search(["SINCE",(@src.sync_at||Time.now.at_beginning_of_year).strftime("%d-%b-%y")]).each do |msg_id|
      begin
        source   = @imap.fetch(msg_id, ['RFC822']).first.attr['RFC822']
        email = TMail::Mail.parse(source)
        #debugger
        metadata = email.keys.find_all{|e|['from','date','to','cc'].include?(e)}.map_hash{|e| [e.to_sym,email[e].to_s]}
        result << {:title=>email.subject,  :content=>email.body, :itype=>@src.itype, :did=>email.message_id, 
          :basetime=>email.date, :metadata=>metadata}
      rescue Net::IMAP::NoResponseError => e
        puts e# send to log file, db, or email
      rescue Net::IMAP::ByeResponseError => e
        puts e# send to log file, db, or email
      rescue => e
        puts e# send to log file, db, or email
      end
    end#each
    result
  end
  
  def close_source()
    begin
      @src.update_attributes!(:sync_at=>Time.now)
      @imap.logout
      @imap.disconnect
    rescue Exception => e
      error "[IMAPCollector::close_source] #{e.inspect}"
    end
  end
end