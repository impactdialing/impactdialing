require 'rails_helper'
require 'application_policy'

shared_examples 'admin and supervisor authorizations' do

  it 'allows admin access to index page' do
    expect(policy_admin.index?).to eq true
  end

  it 'returns false if the user is a supervisor' do
    expect(policy_supervisor.index?).to eq false
  end

  it 'returns true if the user is an administrator' do
    expect(policy_admin.create?).to eq true
  end

  it 'returns false if the user is a supervisor trying to create' do
    expect(policy_supervisor.create?).to eq false
  end

  it 'returns true if the user is an administrator' do
    expect(policy_admin.show?).to eq true
  end

  it 'returns false if the user is a supervisor' do
    expect(policy_supervisor.show?).to eq false
  end

end

shared_context 'user authorization' do
  let(:supervisor) { create(:user, {role: 'supervisor'}) }
  let(:admin) { create(:user) }
end

describe ApplicationPolicy do
  include_context 'user authorization'


  context 'the script class' do
    let(:script) { create(:script) }
    let(:policy_admin) { ScriptPolicy.new(admin, script) }
    let(:policy_supervisor) { ScriptPolicy.new(supervisor, script) }

    # show, edit, new, update, destroy, questions_answered,
    # possible_responses_answered, archived, restore

    it_behaves_like 'admin and supervisor authorizations'
  end

  context 'the campaign class' do
    let(:campaign) { create(:campaign) }
    let(:policy_admin) { CampaignPolicy.new(admin, campaign) }
    let(:policy_supervisor) { CampaignPolicy.new(supervisor, campaign) }

    # new, show, edit, update, destroy, archived, restore, can_change_script

    it_behaves_like 'admin and supervisor authorizations'
  end

  context 'the caller class' do
    let(:caller) { create(:caller) }
    let(:policy_admin) { CallerPolicy.new(admin, caller) }
    let(:policy_supervisor) { CallerPolicy.new(supervisor, caller) }

    # new, show, edit, update, destroy, @@reassign_to_campaign, @@usage, @@call_details,
    # archived, restore, type_name,

    it_behaves_like 'admin and supervisor authorizations'
  end
end
