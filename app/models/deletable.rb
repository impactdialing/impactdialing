module Deletable
  module ClassMethods
  end

  module InstanceMethods
    def restore
      self.active = true
    end

    def delete
      self.active = false
    end
  end

  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods

    receiver.scope :by_updated, -> { order('updated_at desc') }
    receiver.scope :deleted, -> { where({:active => false}) }
    receiver.scope :active, -> { where({:active => true}) }
    receiver.scope :for_account, -> (account) { where(["account_id = ?", account.id]) }
  end
end

