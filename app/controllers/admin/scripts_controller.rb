module Admin
  class ScriptsController < AdminController
    def index
      @scripts = Script.by_updated.paginate(:per_page => 25, :page => params[:page])
    end

    def restore
      Script.find(params[:script_id]).tap do |c|
        c.restore
        c.save
      end
      redirect_to admin_scripts_path
    end
  end
end
