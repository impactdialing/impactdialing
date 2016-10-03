class Report::Answers::Answers
  attr_reader :record, :from_date, :to_date

private
  def rows
    [
      {heading: '<b>Dials per caller per hour</b>', number: :dial_rate},
      {heading: '<b>Answers per caller per hour</b>', number: :answer_rate},
      {heading: '<b>Average call length</b>', number: :average_call_length}
    ]
  end

  def headers
    headers = ['Answer', 'Number', 'Percentage']
  end

end  
