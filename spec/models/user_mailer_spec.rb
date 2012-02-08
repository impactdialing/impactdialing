require "spec_helper"

describe UserMailer do
  include WhiteLabeling

  before(:each) do
    @uakari = mock
    Uakari.stub(:new).and_return(@uakari)
    @mailer = UserMailer.new
  end

  it "delivers confirmation for uploaded voter list" do
    domain = "dc-London"
    @uakari.should_receive(:send_email).with(
        {
            :message => {
                :subject => anything,
                :html => anything,
                :from_name => "dc-London",
                :from_email => "andrew@dc-london.com",
                :to_email => anything
            }
        })
    @mailer.voter_list_upload({'success' => ['true']}, domain, "test@email.com")

  end

end
