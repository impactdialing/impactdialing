class ScriptsController < ClientController
  layout 'v2'
  include DeletableController

  def type_name
    'script'
  end

  def index
    @scripts = @user.scripts.active.paginate(:page => params[:page])
    #@scripts = Script.paginate :page => params[:page], :conditions =>"active=1 and user_id=#{@user.id}", :order => 'name'
  end
end
