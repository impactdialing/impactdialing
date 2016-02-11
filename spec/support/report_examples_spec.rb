shared_examples_for 'any form with date picker' do
  let(:date_picker_button_text){ 'Update date range' }

  scenario 'change from and to dates when button clicked' do
    visit target_url
    fill_in 'From:', with: '02/01/2016'
    fill_in 'To:', with: '02/14/2016'
    click_on date_picker_button_text
  end
end
