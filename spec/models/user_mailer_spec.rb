require "spec_helper"

describe UserMailer do
  let(:white_labeled_email){ "info@stonesphones.com" }
  let(:white_label){ "stonesphonesdialer" }

  before(:each) do
    @mandrill = double
    @mailer = UserMailer.new
    @mailer.stub(:email_domain).and_return({"email_addresses"=>["email@impactdialing.com", white_labeled_email]})
  end

  it "delivers confirmation for uploaded voter list" do
    domain = "dc-London"
    @mailer.should_receive(:send_email).with(anything)
    @mailer.voter_list_upload({'success' => ['true']}, domain, "test@email.com", 'test')

  end

  it "defaults from_email to email@impactdialing.com when unverified" do
    @mailer.white_labeled_email("unverified@email.com").should == "email@impactdialing.com"
  end

  it "uses white labeled email when verified" do
    #WhiteLabeling.stub(:white_labeled_email).and_return(white_labeled_email)
    mandrill = double
    Mandrill::API.should_receive(:new).and_return(mandrill)
    mandrill.should_receive(:call).with('senders/domains').and_return([{"domain"=> "stonesphonesdialer"}])
    UserMailer.new.white_labeled_email(white_label).should == white_labeled_email
  end

end
