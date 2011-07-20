module Client
  class ScriptsController < ::ScriptsController
    layout 'client'

    def deleted
      render 'scripts/deleted'
    end
  end
end
