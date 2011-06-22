module DeletableController
  def class_constant
    type_name.capitalize.constantize
  end

  def deleted
    self.instance_variable_set("@#{type_name.pluralize}", class_constant.deleted.for_user(@user).paginate(:page => params[:page], :order => 'id desc'))
  end

  def restore
    class_constant.find(params["#{type_name}_id"]).tap do |s|
      s.restore
      s.save
    end
    redirect_to :back
  end
end
