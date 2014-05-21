require 'github/markup'

class ScriptText < ActiveRecord::Base
  attr_accessible :content, :script_id, :script_order

  validates :content, presence: true
  validates :script, presence: true
  validates :script_order, presence: true, numericality: true

  belongs_to :script

# private
  def markdown_content
    @markdown_content ||= GitHub::Markup.render("ScriptText:#{id}.md", content)
  end

# public
  def as_json(options)
    super({
      methods: [:markdown_content]
    })
  end
end
