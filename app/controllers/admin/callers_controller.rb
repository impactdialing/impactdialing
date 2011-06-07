module Admin
  class CallersController < AdminController
    def index
      @callers = Caller.by_updated.paginate(:per_page => 25, :page => params[:page])
    end

    def restore
      Caller.find(params[:caller_id]).tap do |c|
        c.restore
        c.save
      end
      redirect_to admin_callers_path
    end
  end
end
