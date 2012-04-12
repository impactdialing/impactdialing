class CreateTableDownloadedReports < ActiveRecord::Migration
  def self.up
    create_table :downloaded_reports do |t|
      t.integer :user_id
      t.string :link
      t.timestamps
    end
    
  end

  def self.down
     drop_table :downloaded_reports
  end
end
