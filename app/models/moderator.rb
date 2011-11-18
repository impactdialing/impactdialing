class Moderator < ActiveRecord::Base
  belongs_to :caller_session
end
