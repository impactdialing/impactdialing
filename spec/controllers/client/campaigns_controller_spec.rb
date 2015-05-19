require 'rails_helper'

describe Client::CampaignsController, :type => :controller do
  let(:account) { create(:account, :activated => true) }
  let(:user) { create(:user, :account => account) }

  let(:question) { create(:question) }
  let(:script) { create(:script) }
  let(:campaign) { create(:campaign) }

  let(:json_params) { {:id => campaign.id, :format => :json} }
  let(:html_params) { json_params.merge({:format => :html}) }

  before do
    allow(controller).to receive(:check_login) { true }
    allow(controller).to receive(:check_tos_accepted) { true }
  end

  describe "html format" do
    context 'when user is admin' do
      let(:admin) { create(:user, {account: campaign.account}) }

      before do
        allow(controller).to receive(:current_user) { admin }
      end

      describe '#index' do
        it 'allows admin access' do
          get(:index, html_params)
          expect(response).to render_template 'index'
        end
      end

      describe '#new' do
        it 'allows admin access' do
          get(:new, html_params)
          expect(response).to render_template 'new'
        end
      end

      describe '#show' do
        it 'allows admin access' do
          get(:show, html_params)
          expect(response).to redirect_to edit_client_campaign_path
        end
      end

      describe '#edit' do
        it 'allows admin access' do
          get(:edit, html_params)
          expect(response).to render_template 'edit'
        end
      end
    end
  end
end




#     # before(:each) do
#     #   login_as user
#     # end
#
#     # it "lists active campaigns" do
#     #   active_campaign = create(:preview, :account => account, :active => true)
#     #   inactive_campaign = create(:power, :account => account, :active => false)
#     #   get :index
#     #   expect(assigns(:campaigns)).to eq([active_campaign])
#     # end
#     #
#     # describe 'show' do
#     #   let(:campaign) {create(:preview, :account => account)}
#     #
#     #   after(:each) do
#     #     expect(response).to be_ok
#     #   end
#     # end
#
#     # it "deletes campaigns" do
#     #   request.env['HTTP_REFERER'] = 'http://referer'
#     #   campaign = create(:preview, :account => account, :active => true)
#     #   delete :destroy, :id => campaign.id
#     #   expect(campaign.reload).not_to be_active
#     #   expect(response).to redirect_to 'http://test.host/client/campaigns'
#     # end
#     #
#     # it "restore campaigns" do
#     #   request.env['HTTP_REFERER'] = 'http://referer'
#     #   campaign = create(:preview, :account => account, :active => true)
#     #   put :restore, :id => campaign.id
#     #   expect(campaign.reload).to be_active
#     #   expect(response).to redirect_to 'http://test.host/client/campaigns'
#     # end
#     #
#     # it "creates a new campaign" do
#     #   script = create(:script, :account => account)
#     #   callers = 3.times.map{create(:caller, :account => account)}
#     #   expect {
#     #     post :create , :campaign => {name: "abc", caller_id:"1234567890", script_id: script.id,
#     #       type: "Preview", time_zone: "Pacific Time (US & Canada)", start_time:  Time.new(2011, 1, 1, 9, 0, 0), end_time: Time.new(2011, 1, 1, 21, 0, 0)}
#     #   }.to change {account.reload.campaigns.size} .by(1)
#     #   campaign = account.campaigns.last
#     #   expect(campaign.type).to eq('Preview')
#     #   expect(campaign.script).to eq(script)
#     #   expect(campaign.account.callers).to eq(callers)
#     # end
#
#   describe "api" do
#     before(:each) do
#       @user = create(:user, account_id: account.id)
#     end
#
#     describe "index" do
#       it "should list active campaigns for an account" do
#         preview_campaign = create(:preview, :account => account, :active => true)
#         predictive_campaign = create(:predictive, :account => account, :active => true)
#         inactive_campaign = create(:power, :account => account, :active => false)
#         get :index, :api_key=> account.api_key, :format => "json"
#         expect(JSON.parse(response.body).length).to eq(2)
#       end
#
#       it "should not list active campaigns for an account with wrong api key" do
#         preview_campaign = create(:preview, :account => account, :active => true)
#         predictive_campaign = create(:predictive, :account => account, :active => true)
#         inactive_campaign = create(:power, :account => account, :active => false)
#         get :index, :api_key=> 'abc12', :format => "json"
#         expect(JSON.parse(response.body)).to eq({"status"=>"error", "code"=>"401", "message"=>"Unauthorized request. Please provide a valid API key or create an account."})
#       end
#     end
#
#     describe "show" do
#       it "should give campaign details" do
#         campaign = create(:predictive, :account => account, :active => true, name: "Campaign 1")
#         get :show, :id=> campaign.id, :api_key=> account.api_key, :format => "json"
#         expect(JSON.parse(response.body)['predictive']['name']).to eq("Campaign 1")
#       end
#     end
#
#     describe "edit" do
#       it "should give campaign details" do
#         predictive_campaign = create(:predictive, :account => account, :active => true, start_time: Time.now, end_time: Time.now, name: "Campaign 2")
#         get :edit, :id=> predictive_campaign.id, :api_key=> account.api_key, :format => "json"
#         expect(JSON.parse(response.body)['predictive']['name']).to eq("Campaign 2")
#       end
#     end
#
#     describe "destroy" do
#       it "should delete campaign" do
#         predictive_campaign = create(:predictive, :account => account, :active => true, start_time: Time.now, end_time: Time.now)
#         delete :destroy, :id=> predictive_campaign.id, :api_key=> account.api_key, :format => "json"
#         expect(response.body).to eq("{\"message\":\"Campaign archived\"}")
#       end
#
#       it "should not delete a campaign from another account" do
#         another_account = create(:account, :activated => true)
#         another_user = create(:user, account_id: another_account.id)
#         predictive_campaign = create(:predictive, :account => account, :active => true, start_time: Time.now, end_time: Time.now)
#         delete :destroy, :id=> predictive_campaign.id, :api_key=> another_account.api_key, :format => "json"
#         expect(response.body).to eq("{\"message\":\"Cannot access campaign.\"}")
#       end
#
#       it "should archive if callers are assigned and return validation error" do
#         caller = create(:caller)
#         predictive_campaign = create(:predictive, :account => account, :active => true, start_time: Time.now, end_time: Time.now, callers: [caller])
#         delete :destroy, :id=> predictive_campaign.id, :api_key=> account.api_key, :format => "json"
#         expect(response.body).to eq({message: "Campaign archived"}.to_json)
#       end
#     end
#
#     describe "create" do
#       it "should create a new campaign" do
#         script = create(:script, :account => account)
#         callers = 3.times.map{create(:caller, :account => account)}
#         expect {
#           post :create , :campaign => {name: "abc", caller_id:"1234567890", script_id: script.id,
#             type: "Preview", time_zone: "Pacific Time (US & Canada)", start_time:  Time.new(2011, 1, 1, 9, 0, 0), end_time: Time.new(2011, 1, 1, 21, 0, 0)}, :api_key=> account.api_key, :format => "json"
#         }.to change {account.reload.campaigns.size} .by(1)
#         expect(JSON.parse(response.body)['campaign']['name']).to  eq('abc')
#       end
#
#       it "should throw validation error" do
#         script = create(:script, :account => account)
#         callers = 3.times.map{create(:caller, :account => account)}
#         expect {
#           post :create , :campaign => {name: "abc", caller_id:"123456", script_id: script.id,
#             type: "Preview", time_zone: "Pacific Time (US & Canada)", start_time:  Time.new(2011, 1, 1, 9, 0, 0), end_time: Time.new(2011, 1, 1, 21, 0, 0)}, :api_key=> account.api_key, :format => "json"
#         }.to change {account.reload.campaigns.size} .by(0)
#         expect(response.body).to eq("{\"errors\":{\"caller_id\":[],\"base\":[\"Caller ID must be a 10-digit North American phone number or begin with \\\"+\\\" and the country code\"]}}")
#       end
#     end
#
#     describe "update" do
#       it "should update an existing campaign" do
#         campaign = create(:predictive, name: "abc", account: account)
#         expect {
#           put :update , id: campaign.id, :campaign => {name: "def"}, :api_key=> account.api_key, :format => "json"
#         }.to change {account.reload.campaigns.size} .by(0)
#         expect(response.body).to  eq("{\"message\":\"Campaign updated\"}")
#       end
#
#       it "should update voter lists for existing campaign" do
#         voter_list = create(:voter_list, enabled: true)
#         campaign = create(:predictive, name: "abc", account: account, voter_lists: [voter_list])
#         expect {
#           put :update , id: campaign.id, :campaign => {name: "def", :voter_lists_attributes=> {"0"=>{"id"=>"#{voter_list.id}", "enabled"=> "0"}}}, :api_key=> account.api_key, :format => "json"
#         }.to change {account.reload.campaigns.size} .by(0)
#         expect(response.body).to  eq("{\"message\":\"Campaign updated\"}")
#         expect(voter_list.reload.enabled).to be_falsey
#       end
#
#       it "should throw validation error" do
#         campaign = create(:predictive, name: "abc", account: account)
#         expect {
#           put :update , id: campaign.id, :campaign => {caller_id: "123"}, :api_key=> account.api_key, :format => "json"
#         }.to change {account.reload.campaigns.size}.by(0)
#         json_errors = {
#           errors: {
#             caller_id: [],
#             base: [I18n.t('activerecord.errors.models.campaign.caller_id_format')]
#           }
#         }
#         expect(response.body).to eq(json_errors.to_json)
#       end
#     end
#
#     describe "archived" do
#       it "should show archived campaigns" do
#         manual_campaign = create(:preview, :account => account, :active => true)
#         inactive_campaign = create(:power, :account => account, :active => false)
#         get :archived, :api_key=> account.api_key, :format => "json"
#         expect(JSON.parse(response.body).length).to eq(1)
#       end
#     end
#
#     describe "restore" do
#       it "should restore inactive campaign" do
#         inactive_campaign = create(:power, :account => account, :active => false)
#         put :restore, id: inactive_campaign.id, :api_key=> account.api_key, :format => "json"
#         expect(response.body).to eq("{\"message\":\"Campaign restored\"}")
#       end
#     end
#   end
# end
