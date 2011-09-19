shared_examples_for 'all controllers of deletable entities' do
  it "can restore a deleted entity" do
    request.env['HTTP_REFERER'] = 'http://referer'
    entity = Factory(type_name, :active => false)
    put :restore, "#{type_name}_id" => entity.id
    entity.reload.should be_active
    response.should redirect_to('http://referer')
  end

  it "lists deleted entities" do
    deleted_entity = Factory(type_name, :account => user.account, :active => false)
    active_entity = Factory(type_name, :account => user.account, :active => true)
    get :deleted
    assigns(type_name.pluralize).should == [deleted_entity]
  end
end
