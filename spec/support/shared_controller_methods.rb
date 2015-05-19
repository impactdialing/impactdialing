# this is the shared CRUD method specs for Client::scripts, campaigns, callers
# model! spec/support/navigation_policy.rb
# maybe? have a 'require shared_controller_methods' at the top of the individual
#   controller specs to run the 'it behaves like' statements inside those files
require 'rails_helper'

shared_examples 'the admin CRUD methods' do
  describe '#index' do
    it 'renders index template' do
      get(:index, html_params)
      expect(response).to render_template 'index'
    end
  end

  describe '#show' do
    it 'allows admin access' do
      get(:show, html_params)
      expect(response).to redirect_to show_redirect
    end
  end

  describe '#edit' do
    it 'allows admin access' do
      get(:edit, html_params)
      expect(response).to render_template 'edit'
    end
  end

  # describe '#create' do, here or in indiv. files?

  describe '#new' do
    it 'allows admin access' do
      get(:new, html_params)
      expect(response).to render_template 'new'
    end
  end

  describe '#destroy' do
    it 'allows admin access' do
      delete(:destroy, html_params)
      expect(response).to redirect_to client_scripts_path
    end
  end

end

shared_examples 'the supervisor CRUD methods' do
  describe '#index' do
    it 'disallows access and redirects to dashboard' do
      get(:index, html_params)
      expect(response).to redirect_to root_url
    end
  end
end
