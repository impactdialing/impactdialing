class DropSeosTable < ActiveRecord::Migration
  def change
    drop_table :seos
  end
end
