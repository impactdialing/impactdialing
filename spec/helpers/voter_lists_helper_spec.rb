require "spec_helper"

describe VoterListsHelper do
  it "loads the robo path for a robo campaign" do
    helper.import_voter_lists_path(Factory(:campaign, :robo => true)).should include('broadcast')
  end

  it "loads the non-robo path for a non-robo campaign" do
    helper.import_voter_lists_path(Factory(:campaign, :robo => false)).should include('client')
  end
end
