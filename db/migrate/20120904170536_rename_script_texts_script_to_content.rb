class RenameScriptTextsScriptToContent < ActiveRecord::Migration
  def change
    rename_column :script_texts, :section, :content
  end
end
