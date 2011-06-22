require "spec_helper"

describe ScriptsController do
  let(:user) { Factory(:user) }

  before(:each) do
    login_as user
  end

  def type_name
    'script'
  end

  it_should_behave_like 'all controllers of deletable entities'
end
