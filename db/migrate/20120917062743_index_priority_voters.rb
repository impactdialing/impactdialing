class IndexPriorityVoters < ActiveRecord::Migration
  def change
    add_index(:voters, [:campaign_id, :enabled, :priority, :status], :name => 'index_priority_voters')
  end
end
