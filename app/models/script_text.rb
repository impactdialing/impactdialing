class ScriptText < ActiveRecord::Base
  attr_accessible :content, :script_id, :script_order

  validates :content, presence: true
  validates :script, presence: true
  validates :script_order, presence: true, numericality: true

  belongs_to :script

  def markdown_content
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::ScriptText, {
      autolink: false,
      fenced_code_blocks: false,
      disable_indented_code_blocks: true,
      hard_wrap: false,
      no_images: true,
      no_intra_emphasis: true,
      no_links: true,
      no_styles: true,
      space_after_headers: true,
      strikethrough: false,
      tables: false,
      with_toc_data: false,
      xhtml: false,
      superscript: false,
      underline: true,
      highlight: false,
      footnotes: false
    })
    markdown.render(content)
  end

  def as_json(options)
    super({
      methods: [:markdown_content]
    })
  end
end

# Trimmed down redcarpet renderer.
# Supports:
# - lists
# - headers (1, 2, 3)
# - double_emphasis
# - emphasis
# - linebreak
# - paragraph
# - blockquote (block_quote)
class Redcarpet::Render::ScriptText < Redcarpet::Render::Base
  def normal_text(text)
    text.gsub('-', '\\-').strip
  end

  def strikethrough(text)
    normal_text(text)
  end

  def header(title, level)
    case level
    when 1
      "\n<h1>#{title}</h1>\n"

    when 2
      "\n<h2>#{title}</h2>\n"

    when 3
      "\n<h3>#{title}</h3>\n"
    end
  end

  def double_emphasis(text)
    "<strong>#{text}</strong>"
  end

  def emphasis(text)
    "<em>#{text}</em>"
  end

  def linebreak
    "\n<br>\n"
  end

  def paragraph(text)
    "\n<p>#{text}</p>\n"
  end

  def block_quote(text)
    "\n<blockquote>#{text}</blockquote>\n"
  end

  def list(content, list_type)
    case list_type
    when :ordered
      "\n<ol>#{content}</ol>\n"
    when :unordered
      "\n<ul>#{content}</ul>\n"
    end
  end

  def list_item(content, list_type)
    case list_type
    when :ordered
      "\n<li>#{content.strip}</li>\n"
    when :unordered
      "\n<li>#{content.strip}</li>\n"
    end
  end
end
