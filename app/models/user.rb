class User < ActiveRecord::Base

  validates_presence_of :uid 
  validates_uniqueness_of :uid 
  validates_presence_of :email 
  validates_uniqueness_of :email 
  
  validates_format_of :email, 
  :with => /^[A-Z0-9._%-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$/i,
  :message => "is invalid" 
  
  
  attr_accessor :password_confirmation 
  attr_accessor :password # virtual attribute
  validates_confirmation_of :password 
  has_many :game
  has_many :query
  #validate :password_non_blank 

  def admin?
    utype == 'admin'
  end
  
  def password 
    @password 
  end 
  
  def password=(pwd) 
    @password = pwd 
    return if pwd.blank? 
    create_new_salt 
    self.hashed_password = User.encrypted_password(self.password, self.salt) 
  end
  
  # Authenticate User by name & password
  def self.authenticate(uid, password) 
    user = self.find_by_uid(uid) 
    if user 
      expected_password = encrypted_password(password, user.salt) if user.salt
      if user.hashed_password && user.hashed_password != expected_password 
        user = nil 
      end 
    end 
    user 
  end 
    

private 
  def self.encrypted_password(password, salt) 
    string_to_hash = password + "wibble" + salt 
    Digest::SHA1.hexdigest(string_to_hash) 
  end

  def create_new_salt 
    self.salt = self.object_id.to_s + rand.to_s 
  end 
  
  def password_non_blank 
    errors.add(:password, "Missing password") if hashed_password.blank? 
  end 
end
