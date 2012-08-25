class MoveScriptsScriptToScriptTexts < ActiveRecord::Migration
  def self.up
    Script.all.each do |script|
      s = script.script_texts.new
      s.section = script.script
      s.save
    end
  end

  def self.down
  end
end
