require 'spec_helper'

describe ScriptText, :type => :model do
  context 'validations' do
    it {is_expected.to validate_presence_of :content}
    it {is_expected.to validate_presence_of :script}
    it {is_expected.to validate_presence_of :script_order}
    it {is_expected.to validate_numericality_of :script_order}
  end

  context '#markdown_content' do
    subject{ ScriptText.new }
    let(:unsupported) do
      """
      ```
      Big code block
      ```

      `small code block`

      http://test.com/

      [http://test.com/](Title Link)

      ~~strikethrough~~

      ~strikenot~

      ***other things***
      """
    end
    let(:expected_unsupported) do
      """
<p>```Big code block```</p>

<p>`small code block`</p>

<p>http://test.com/</p>

<p>[http://test.com/](Title Link)</p>

<p>~~strikethrough~~</p>

<p>~strikenot~</p>

<p>*<strong>other things</strong>*</p>
"""
    end

    it 'handles headings' do
      subject.content = '# Hello'
      expect(subject.markdown_content).to eq "\n<h1>Hello</h1>\n"
    end
    it 'handles paragraph quotes' do
      subject.content = '> paragraph'
      expect(subject.markdown_content).to eq "\n<blockquote>\n<p>paragraph</p>\n</blockquote>\n"
    end
    it 'handles bulleted lists' do
      subject.content = '- hello'
      expect(subject.markdown_content).to eq "\n<ul>\n<li>hello</li>\n</ul>\n"
    end
    it 'handles numbered lists' do
      subject.content = '1. hi'
      expect(subject.markdown_content).to eq "\n<ol>\n<li>hi</li>\n</ol>\n"
    end
    it 'handles italicize' do
      subject.content = '*italic*'
      expect(subject.markdown_content).to eq "\n<p><em>italic</em></p>\n"
    end
    it 'handles bold' do
      subject.content = '**bold**'
      expect(subject.markdown_content).to eq "\n<p><strong>bold</strong></p>\n"
    end
    it 'does not handle anything else' do
      subject.content = unsupported
      expect(subject.markdown_content).to eq expected_unsupported
    end
    it 'does not cause segfaults when triple emphasis markers are used' do
      content = "Hi is __________there? Hi, this is_________."
      expected = "\n<p>Hi is________<strong>there? Hi, this is</strong>_______.</p>\n"
      subject.content = content
      expect(subject.markdown_content).to eq expected
    end
  end
end
