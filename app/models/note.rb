class Note < ActiveRecord::Base
  attr_accessible :note, :script_id, :script_order

  validates :note, presence: true
  validates :script, presence: true
  validates :script_order, presence: true, numericality: true

  belongs_to :script, inverse_of: :questions

  def self.note_texts(note_ids)
    texts = []
    notes = Note.select("id, note").where("id in (?)",note_ids).order('id')
    note_ids.each_with_index do |note_id, index|
      unless notes.collect{|x| x.id}.include?(note_id)
        texts << ""
      else
        texts << notes.detect{|at| at.id == note_id}.note
      end
    end
    texts
  end
end

# ## Schema Information
#
# Table name: `notes`
#
# ### Columns
#
# Name                | Type               | Attributes
# ------------------- | ------------------ | ---------------------------
# **`id`**            | `integer`          | `not null, primary key`
# **`note`**          | `text`             | `default(""), not null`
# **`script_id`**     | `integer`          | `not null`
# **`script_order`**  | `integer`          |
#
