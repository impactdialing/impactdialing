require 'spec_helper'

describe ReportWebUIStrategy, :type => :model do
  include ExceptionMethods

  describe 'a new instance' do
    let :user do
      double
    end
    let :campaign do
      double({
        id: 123,
        name: 'Champ Agne',
        account_id: 111
      })
    end
    let :mailer do
      double({
        deliver_download: '',
        deliver_download_failure: '',
        deliver_exception_notification: ''
      })
    end
    let :s3_link do
      double
    end
    let :s3_obj do
      double({
        url_for: s3_link
      })
    end
    let :s3 do
      double({
        object: s3_obj
      })
    end
    let :exception do
      fake_exception
    end

    before do
      allow(UserMailer).to receive(:new){ mailer }
    end

    context '.new(result, user, campaign, exception)' do
      it 'stores args as ivars' do
        [
          ['success',nil],
          ['failure',exception]
        ].each do |args|
          obj = ReportWebUIStrategy.new(args.first, user, campaign, args.last)
          expect(obj.instance_variable_get(:@result)).to eq args.first
          expect(obj.instance_variable_get(:@user)).to eq user
          expect(obj.instance_variable_get(:@campaign)).to eq campaign
          expect(obj.instance_variable_get(:@exception)).to eq args.last
        end
      end

      context 'when result arg is "success"' do
        let :obj do
          ReportWebUIStrategy.new('success', user, campaign, nil)
        end
        let :params do
          {campaign_name: campaign.name}
        end

        describe '#response({campaign_name: "Some Name"})' do
          before do
            allow(AmazonS3).to receive(:new){ s3 }
            DownloadedReport.stub_chain(:using, :create)
          end
          after do
            obj.response(params)
          end

          it 'retrieves the S3 download link that expires in 24 hours' do
            expect(s3_obj).to receive(:url_for).with(:read, expires: 24.hours.to_i)
            expect(s3).to receive(:object)
              .with('download_reports', "#{campaign.name}.csv"){ s3_obj }
          end

          it 'creates a DownloadedReport obj' do
            downloaded_report = double
            expect(downloaded_report).to receive(:create).with({
              link: s3_link.to_s, user: user, campaign_id: campaign.id
            })
            expect(DownloadedReport).to receive(:using).with(:master){ downloaded_report }
          end

          it 'tells @mailer to deliver_download link' do
            expect(mailer).to receive(:deliver_download).with(user, s3_link.to_s)
          end
        end
      end

      context 'when result is "failure"' do
        let :obj do
          ReportWebUIStrategy.new('failure', user, campaign, exception)
        end

        describe '#response({these_args_ignored: true})' do
          let :params do
            {}
          end

          after do
            obj.response(params)
          end

          it 'tells @mailer to deliver_download_failure end-user notification' do
            expect(mailer).to receive(:deliver_download_failure)
              .with(user, campaign)
          end

          it 'tells @mailer to deliver_exception_notification for devs etc' do
            expect(mailer).to receive(:deliver_exception_notification)
              .with("Campaign: #{campaign.name}; Account ID: #{campaign.account_id}", exception)
          end
        end
      end

    end

  end
end