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
      helper.system_column_headers("foo",@account).should == [["(Discard this column)", nil], ["foo", "foo"], ["Barbaz", "barbaz"], ["Add custom field...", "custom"]]
    end

    it "returns a list of all custom fields along with the others" do
      custom_field = "baz"
      Factory(:custom_voter_field, :name => "baz", :account => @account)
      helper.system_column_headers("foo",@account).should == [["(Discard this column)", nil], ["foo", "foo"],["Barbaz", "barbaz"], ["#{custom_field}", custom_field], ["Add custom field...", "custom"]]
    end
  end
end
