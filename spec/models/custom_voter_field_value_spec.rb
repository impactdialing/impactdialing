require "spec_helper"

describe CustomVoterFieldValue do

  let(:custom_field) {Factory(:custom_voter_field)}
  let(:voter) { Factory(:voter, :Phone => "34953904782") }

  it "stores a voter custom attribute value" do
    value = 'foo'
    Factory(:custom_voter_field_value, :voter => voter, :custom_voter_field => custom_field, :value => value)
    CustomVoterFieldValue.voter_fields(voter,custom_field).first.value.should == value
  end

  it "lists all custom field values for a voter" do
    new_field = Factory(:custom_voter_field)
    val1 = Factory(:custom_voter_field_value, :voter => voter, :custom_voter_field => custom_field, :value => 'foo' )
    val2 = Factory(:custom_voter_field_value, :voter => voter, :custom_voter_field => new_field, :value => 'bar')
    CustomVoterFieldValue.for(voter).should == [val1, val2]
  end

  it { should validate_presence_of :voter_id }
  it { should validate_presence_of :custom_voter_field_id }
end
