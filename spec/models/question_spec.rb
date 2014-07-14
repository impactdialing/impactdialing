require "spec_helper"

describe Question, :type => :model do
  include Rails.application.routes.url_helpers

  context 'validations' do
    it {is_expected.to validate_presence_of :text}
    it {is_expected.to validate_presence_of :script}
    it {is_expected.to validate_presence_of :script_order}
    it {is_expected.to validate_numericality_of :script_order}
  end

  let(:script) { create(:script) }
  let(:campaign) { create(:campaign, :script => script) }
  let(:voter) { create(:voter, :campaign => campaign) }

  it "should return questions answered in a time range" do
    now = Time.now
    question = create(:question, :script => script)
    answer1 = create(:answer, :voter => voter, campaign: campaign, :possible_response => create(:possible_response), :question => question, :created_at => (now - 2.days))
    answer2 = create(:answer, :voter => voter, campaign: campaign, :possible_response => create(:possible_response), :question => question, :created_at => (now - 1.days))
    answer3 = create(:answer, :voter => voter, campaign: campaign, :possible_response => create(:possible_response), :question => question, :created_at => (now + 1.minute))
    answer4 = create(:answer, :voter => voter, campaign: campaign, :possible_response => create(:possible_response), :question => question, :created_at => (now + 1.day))
    expect(question.answered_within(now, now + 1.day, campaign.id)).to eq([answer3, answer4])
    expect(question.answered_within(now + 2.days, now + 3.days, campaign.id)).to eq([])
    expect(question.answered_within(now, now + 1.day, campaign.id)).to eq([answer3, answer4])

  end

  it "returns questions answered by a voter" do
    answered_question = create(:question, :script => script, :text => "Q1?")
    pending_question = create(:question, :script => script, :text => "Q2?")
    create(:answer, :voter => voter, :possible_response => create(:possible_response), :question => answered_question, :created_at => (Time.now - 2.days))
    expect(Question.answered_by(voter)).to eq([answered_question])
  end

  it "returns all questions unanswered when voter has not answered any question" do
    q1 = create(:question, :script => script, :text => "Q1?")
    q2 = create(:question, :script => script, :text => "Q2?")
    expect(script.questions.not_answered_by(voter)).to eq([q1, q2])
  end

  it "returns questions not answered by a voter" do
    answered_question = create(:question, :script => script, :text => "Q1?")
    pending_question = create(:question, :script => script, :text => "Q2?")
    create(:answer, :voter => voter, :possible_response => create(:possible_response), :question => answered_question, :created_at => (Time.now - 2.days))
    expect(script.questions.not_answered_by(voter)).to eq([pending_question])
  end

  describe "question texts" do
    let(:script) { create(:script) }
    let(:campaign) { create(:campaign, :script => script) }
    let(:voter) { create(:voter, :campaign => campaign) }

    it "should return the text of all questions not deleted" do
      question1 = create(:question, text: "Q1", script: script)
      question2 = create(:question, text: "Q12", script: script)
      expect(Question.question_texts([question1.id, question2.id])).to eq(["Q1", "Q12"])
    end

    it "should return the text of all questions not deleted in correct order" do
      question1 = create(:question, text: "Q1", script: script)
      question2 = create(:question, text: "Q12", script: script)
      expect(Question.question_texts([question2.id, question1.id])).to eq(["Q12", "Q1"])
    end

    it "should return the blank text for questions that dont exist" do
      question1 = create(:question, text: "Q1", script: script)
      question2 = create(:question, text: "Q12", script: script)
      expect(Question.question_texts([question2.id, 12343 ,question1.id])).to eq(["Q12","", "Q1"])
    end


  end

end
