require 'rails_helper'
require 'application_policy'

shared_examples 'admin and supervisor authorizations' do
  context 'user is admin' do
    let(:admin) { build(:user) }

    it 'allows access to index page' do
      expect(policy_admin.index?).to eq true
    end

    it 'allows access to #create' do
      expect(policy_admin.create?).to eq true
    end

    it 'allows access to #new' do
      expect(policy_admin.new?).to eq true
    end

    it 'allows access to show page' do
      expect(policy_admin.show?).to eq true
    end

    it 'allows access to #edit' do
      expect(policy_admin.edit?).to eq true
    end

    it 'allows access to #update' do
      expect(policy_admin.update?).to eq true
    end

    it 'allows access to #destroy' do
      expect(policy_admin.destroy?).to eq true
    end
  end

  context 'user is supervisor' do
    let(:supervisor) { build(:user, {role: 'supervisor'}) }

    it 'disallows access to index page' do
      expect(policy_supervisor.index?).to eq false
    end
    it 'disallows access to #create' do
      expect(policy_supervisor.create?).to eq false
    end

    it 'disallows access to #show' do
      expect(policy_supervisor.show?).to eq false
    end

    it 'disallows access to #new' do
      expect(policy_supervisor.new?).to eq false
    end

    it 'disallows access to #edit' do
      expect(policy_supervisor.edit?).to eq false
    end

    it 'disallows access to #update' do
      expect(policy_supervisor.update?).to eq false
    end

    it 'disallows access to #destroy' do
      expect(policy_supervisor.destroy?).to eq false
    end
  end
end

describe ApplicationPolicy do

  context 'the script class' do
    let(:script) { build(:script) }
    let(:policy_admin) { ScriptPolicy.new(admin, script) }
    let(:policy_supervisor) { ScriptPolicy.new(supervisor, script) }

    it_behaves_like 'admin and supervisor authorizations'
  end

  context 'the campaign class' do
    let(:campaign) { build(:campaign) }
    let(:policy_admin) { CampaignPolicy.new(admin, campaign) }
    let(:policy_supervisor) { CampaignPolicy.new(supervisor, campaign) }

    it_behaves_like 'admin and supervisor authorizations'
  end

  context 'the caller class' do
    let(:caller) { build(:caller) }
    let(:policy_admin) { CallerPolicy.new(admin, caller) }
    let(:policy_supervisor) { CallerPolicy.new(supervisor, caller) }

    it_behaves_like 'admin and supervisor authorizations'
  end
end
