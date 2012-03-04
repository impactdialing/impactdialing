module DeletableController

  def class_constant
    type_name.capitalize.constantize
  end

  def load_deleted
    self.instance_variable_set("@#{type_name.pluralize}", class_constant.deleted.for_account(@user.account).paginate(:page => params[:page], :order => 'id desc'))
  end

  def restore
    class_constant.find(params["#{type_name}_id"]).tap do |s|
      s.active = true
      s.save
    end
    redirect_to :back
  end

  def self.included(receiver)
    receiver.before_filter :load_deleted, :only => [:deleted]
  end
end
