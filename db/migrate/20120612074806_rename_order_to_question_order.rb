class RenameOrderToQuestionOrder < ActiveRecord::Migration
  def self.up
    rename_column :questions, :order, :question_order
  end

  def self.down
    rename_column :questions, :question_order, :order
  end
end
