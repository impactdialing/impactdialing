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
    let(:segfaulting_text) do
      [
        "Hi this is ",
        "____Your Name____.   ",
        "Is __Resident Name_ at home?\r\n\r\n", # segfaults
        "Is _Resident Name_ at home?\r\n\r\n", # segfaults
        "Hi, my name is ",
        "_Your Name___. ", # segfaults
        "I am a local resident calling for the “Bonaccorsi for Fremont City Council” Campaign.\r\n\r\n",
        "David Bonaccorsi grew up in Fremont and is a champion for all things Fremont. He has been endorsed by the Democratic Party, Alameda Labor Council, as well as important local leaders including Congressman Mike Honda, City Councilmembers Anu Natarajan, Sue Chan and Vinnie Bacon, School Board trustees Lara Calvert-York, Desrie Campbell and Ann Crosbie.\r\n\r\nCan we count on you to vote for David Bonaccorsi for Fremont City Council on November 4th?\r\n\r\n<If Undecided> David Bonaccorsi is the longest serving Fremont Planning commissioner. He has fought for a well-planned downtown and has the experience to make the new Innovation District a reality; David has been endorsed by the Sierra Club and, as a past President of the Fremont Education Foundation, will ensure continued cooperation between the city and our schools. We hope you will vote for David Bonaccorsi on November 4th. Thank you for your time. <end>"
      ]
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
    it 'does not cause segfaults when segfaulting_text is used' do
      segfaulting_text.each do |text|
        subject.content = text
        expect{subject.markdown_content}.to_not raise_error{ Exception }
      end
    end
  end
end

# ## Schema Information
#
# Table name: `script_texts`
#
# ### Columns
#
# Name                | Type               | Attributes
# ------------------- | ------------------ | ---------------------------
# **`id`**            | `integer`          | `not null, primary key`
# **`script_id`**     | `integer`          |
# **`content`**       | `text`             |
# **`script_order`**  | `integer`          |
#
