require "spec_helper"

describe CustomVoterFieldValue do

  let(:custom_field) {Factory(:custom_voter_field)}
  let(:voter) { Factory(:voter, :Phone => "34953904782") }

  it "stores a voter custom attribute value" do
    value = 'foo'
    Factory(:custom_voter_field_value, :voter => voter, :custom_voter_field => custom_field, :value => value)
    CustomVoterFieldValue.voter_fields(voter,custom_field).first.value.should == value
  end

end
