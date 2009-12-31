# Each game in pagehunt
class Game < ActiveRecord::Base
  belongs_to :user
  
  named_scope :valid, {:conditions=>["score > ?", 0]}
end
