# Each game in pagehunt
class Game < ActiveRecord::Base
  belongs_to :user
  
  named_scope :valid, {:conditions=>["score > ? and hidden_flag != 1", 0]}
  named_scope :displayable, {:conditions=>["user_id not in (1,23)"]}
end
