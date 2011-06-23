class ScriptsController < ClientController
  layout 'v2'
  include DeletableController

  def type_name
    'script'
  end

  def index
    @scripts = @user.scripts.active.paginate(:page => params[:page])
  end

  def new
    @fields = ["CustomID","FirstName","MiddleName","LastName","Suffix","Age","Gender","Phone","Email"]
    @breadcrumb=[{"Scripts"=>"/client/scripts"},"Add Script"]
    @label = 'New Script'

    @script = @user.scripts.new(:name => 'Untitled Script')
    @incompletes = {}
    @voter_fields = []
    @numResults = 1
    @numNotes = 0
  end
end
