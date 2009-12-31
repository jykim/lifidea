class Notifier < ActionMailer::Base
  

  def warning(title)
    subject    "LiFiDeA Notifier : #{title}"
    recipients 'myleo.jerry@gmail.com'
    from       'lifidea@gmail.com'
    sent_on    Time.now
    
    body       :message => "Reporting Error on #{title}"
  end

end
