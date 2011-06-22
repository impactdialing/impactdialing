class ScriptsController < ClientController
  layout 'v2'
  include DeletableController

  def type_name
    'script'
  end
end
