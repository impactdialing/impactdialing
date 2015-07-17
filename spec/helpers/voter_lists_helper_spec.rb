require 'rails_helper'

describe VoterListsHelper, :type => :helper do
  describe 'system column headers' do
    before(:each) do
      @original_columns = VoterList::VOTER_DATA_COLUMNS
      silence_warnings { VoterList::VOTER_DATA_COLUMNS = {"foo"=>"foo", "barbaz"=>"Barbaz", "custom_id" => "ID"} }
      @account = create(:account)
    end

    after(:each) do
      silence_warnings { VoterList::VOTER_DATA_COLUMNS = @original_columns }
    end

    it "returns a list of all available voter attributes as well as not available" do
      expect(helper.system_column_headers("foo",@account)).to eq([["(Discard this column)", nil], ["foo", "foo"], ["Barbaz", "barbaz"], ["ID", "custom_id"], ["Add custom field...", "custom"]])
    end

    it "returns a list of all custom fields along with the others" do
      custom_field = "baz"
      create(:custom_voter_field, name: "baz", account: @account)
      expect(helper.system_column_headers("foo",@account)).to eq([["(Discard this column)", nil], ["foo", "foo"],["Barbaz", "barbaz"], ["ID", "custom_id"], ["#{custom_field}", custom_field], ["Add custom field...", "custom"]])
    end

    it "excludes custom_id when use_custom_id is false" do
      expect(helper.system_column_headers("foo", @account, false)).to eq([["(Discard this column)", nil], ["foo", "foo"], ["Barbaz", "barbaz"], ["Add custom field...", "custom"]])

    end
  end

  describe 'auto-selecting matches between csv headers and known columns (system or custom)' do
    let(:account){ create(:account) }

    it 'returns the value of a matching system column' do
      selected_name_match = helper.selected_system_or_custom_header_for('FirstName', account)
      expect(selected_name_match).to eq 'first_name'

      selected_phone_match = helper.selected_system_or_custom_header_for('Phone', account)
      expect(selected_phone_match).to eq 'phone'
    end

    it 'returns the value of a matching custom column' do
      create(:custom_voter_field, name: 'Last donation', account: account)

      selected_x_match = helper.selected_system_or_custom_header_for('Last donation', account)
      expect(selected_x_match).to eq 'Last donation'
    end

    it 'strips leading/trailing whitespace from csv_header for comparison' do
      create(:custom_voter_field, name: 'SupportingMember', account: account)

      selected_y_match = helper.selected_system_or_custom_header_for(' SupportingMember ', account)
      expect(selected_y_match).to eq 'SupportingMember'
    end
  end
end
