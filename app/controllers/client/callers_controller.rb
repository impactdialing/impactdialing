module Client
  class CallersController < ClientController
    include DeletableController

    def type_name
      'caller'
    end
  end
end
