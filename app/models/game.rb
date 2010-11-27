# Each game in pagehunt
class Game < ActiveRecord::Base
  belongs_to :user
  
  scope :valid, {:conditions=>["score > ? and hidden_flag != 1", 0]}
  scope :displayable, {:conditions=>["user_id not in (1,23)"]}
end
