require "spec_helper"

describe VoterListsHelper do
  describe 'system column headers' do
    before(:each) do
      @original_columns = VoterList::VOTER_DATA_COLUMNS
      silence_warnings { VoterList::VOTER_DATA_COLUMNS = {"foo"=>"foo", "barbaz"=>"Barbaz"} }
      @account = Factory(:account)
    end

    after(:each) do
      silence_warnings { VoterList::VOTER_DATA_COLUMNS = @original_columns }
    end

    it "returns a list of all available voter attributes as well as not available" do
      helper.system_column_headers("foo",@account).should == [["Not available", nil], ["foo", "foo"], ["Barbaz", "barbaz"]]
    end

    it "returns a list of all available voter attributes as well an unknown attribute" do
      helper.system_column_headers("bar", @account).should == [["Not available", nil], ["bar (Custom)", "bar"], ["foo", "foo"],["Barbaz", "barbaz"]]
    end

    it "returns a list of all custom fields along with the others" do
      custom_field = "baz"
      Factory(:custom_voter_field, :name => "baz", :account => @account)
      helper.system_column_headers("foo",@account).should == [["Not available", nil], ["foo", "foo"],["Barbaz", "barbaz"], ["#{custom_field} (Custom)", custom_field]]
    end
  end
end
