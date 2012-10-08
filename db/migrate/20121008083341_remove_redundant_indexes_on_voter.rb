class RemoveRedundantIndexesOnVoter < ActiveRecord::Migration
  def up
    drop_index :voters, name: 'index_voters_on_campaign_id'
    drop_index :voters, name: 'index_voters_on_campaign_id_and_status'
    drop_index :voters, name: 'index_voters_on_Phone'
  end

  def down
    add_index :voters, [:campaign_id], :name => :index_voters_on_campaign_id
    add_index :voters, [:campaign_id, :status], :name => :index_voters_on_campaign_id_and_status
    add_index :voters, [:Phone], :name => :index_voters_on_Phone
  end
end
