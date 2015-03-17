module Deletable
  module ClassMethods
    def by_updated
      order('updated_at DESC')
    end

    def deleted
      archived
    end
    def archived
      where(active: false)
    end

    def active
      where(active: true)
    end

    def for_account(account)
      where(account_id: account.id)
    end
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
  end
end

