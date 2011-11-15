require "spec_helper"

describe VoterListsHelper do
  it "loads the robo path for a robo campaign" do
    helper.import_voter_lists_path(Factory(:campaign, :robo => true)).should include('broadcast')
  end

  it "loads the non-robo path for a non-robo campaign" do
    helper.import_voter_lists_path(Factory(:campaign, :robo => false)).should include('client')
  end

  describe 'system column headers' do
    before(:each) do
      @original_columns = VoterList::VOTER_DATA_COLUMNS
      silence_warnings { VoterList::VOTER_DATA_COLUMNS = {"foo"=>"foo", "barbaz"=>"Barbaz"} }
    end

    after(:each) do
      silence_warnings { VoterList::VOTER_DATA_COLUMNS = @original_columns }
    end

    it "returns a list of all available voter attributes as well as not available" do
      helper.system_column_headers("foo").should == [["Not available", nil], ["foo", "foo"], ["Barbaz", "barbaz"]]
    end

    it "returns a list of all available voter attributes as well an unknown attribute" do
      helper.system_column_headers("bar").should == [["Not available", nil], ["bar (Custom)", "bar"], ["foo", "foo"],["Barbaz", "barbaz"]]
    end

    it "returns a list of all custom fields along with the others" do
      custom_field = "baz"
      Factory(:custom_voter_field, :name => "baz", :account => Factory(:account))
      helper.system_column_headers("foo").should == [["Not available", nil], ["foo", "foo"],["Barbaz", "barbaz"], ["#{custom_field} (Custom)", custom_field]]
    end
  end
end
