require 'rails_helper'
require 'navigation_policy'

feature 'the headless NavigationPolicy' do
  let(:supervisor) { create(:user, {role: 'supervisor'}) }
  let(:admin) { create(:user) }
  subject { NavigationPolicy }

  describe 'the authorization policy' do
    it 'disallows access to supervisor' do
      web_login_as(supervisor)
      visit client_scripts_path
      expect(page).to have_content 'Only an administrator can access this page.'
    end

    it 'allows access to administrator' do
      web_login_as(admin)
      visit client_scripts_path
      expect(page).to have_content 'View archived scripts'
    end
  end
end


# require 'spec_helper'
#
# describe ArticlePolicy do
#   subject { ArticlePolicy.new(user, article) }
#
#   let(:article) { FactoryGirl.create(:article) }
#
#   context "for a visitor" do
#     let(:user) { nil }
#
#     it { should     permit(:show)    }
#
#     it { should_not permit(:create)  }
#     it { should_not permit(:new)     }
#     it { should_not permit(:update)  }
#     it { should_not permit(:edit)    }
#     it { should_not permit(:destroy) }
#   end
#
#   context "for a user" do
#     let(:user) { FactoryGirl.create(:user) }
#
#     it { should permit(:show)    }
#     it { should permit(:create)  }
#     it { should permit(:new)     }
#     it { should permit(:update)  }
#     it { should permit(:edit)    }
#     it { should permit(:destroy) }
#   end
# end
# require 'rails_helper'
#
# feature 'include an "add a new campaign" link' do
#
#
#   describe 'adding a new caller' do
#     it 'adds a link to new_client_campaign_path if there are no callers' do
#       visit client_callers_path
#       click_on 'add a new campaign'
#       expect(page).to have_content 'New campaign'
#     end
#
#     it 'does not add a link to new_client_campaign_path if there is a caller' do
#       web_login_as(admin)
#       create(:caller, account: admin.account)
#       visit client_callers_path
#       expect(page).not_to have_content 'add a new campaign'
#     end
#   end
# end
