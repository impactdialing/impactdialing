Integration Testing

Most work done so far on integration testing can be replaced w/ the twilio-test-toolkit (ttt), which provides rspec matchers and helper methods for mimicing Twilio callback requests and verifying TwiML output. ttt will reduce overhead of the tests it can be used in.

The caller ui javascript tests done so far forgo exercising background jobs (which includes integration points where our app must make requests to external services) in order to stub external services, rather than stubbing external services at the request layer. Our integration tests will exercise our entire stack and optionally be able to exercise external services (Twilio, Pusher, Mandrill, etc) as well. Our integration tests must confirm that the app is making appropriate requests to external services at appropriate times.

PusherFake will act as a stand-in for the real pusher service. Periodically, the library should be reviewed for parity w/ the real pusher service and updated as needed.

Mandrill/MailChimp API requests are stubbed w/ WebMock in unit tests, however there are no integration tests around emails (transactional or otherwise).

Twilio API requests are also stubbed w/ WebMock in unit tests, no integration tests around these requests either.

Most Twilio API requests originate from background jobs. It would be ideal to write tests like:

feature 'Dialing in Preview Mode' do
	before(:all) do
		create(:preview)
		create(:voters)
		login(caller)
		start_calling # Mimic Twilio request POST to app/start_calling
	end
	before(:each) do
		click_button 'Dial'
		expect(page).to have_content 'Dialing...'
		process_jobs # kick-off resque/sidekiq
	end
	after(:all) do
		logout(caller)
	end
	scenario 'Call is answered by human' do
		expect(page).to have_content 'On call'
		click_button 'Hangup'
		process_jobs
		fill_in_survey
		click_button 'Save and continue'
	end
	scenario 'Call is answered by machine with machine detection off and caller drops message' do
		expect(page).to have_content 'On call'
		click_button 'Drop message'
		process_jobs
		fill_in_survey
		click_button 'Save and continue'
	end
	scenario 'Call is answered by machine with machine detection on and caller successfully drops a message' do
		expect(page).to have_content 'On call'
		click_button 'Drop message'
		process_jobs
		expect(page).to have_content 'Message delivered'
		fill_in_survey
		click_button 'Save and continue'
	end
	scenario 'Call is answered by machine with machine detection on and message drops automatically' do
		expect(page).to have_content 'Waiting to dial'
	end
	scenario 'Call is answered by machine with machine detection off and caller hangs up' do
		expect(page).to have_content 'On call'
		click_button 'Hangup'
		process_jobs
		fill_in_survey
	end 
end

Takeaway being that we're not explicitly setting request expectations in the tests themselves. Ideally, these expectations will be implied by way of the data created for each set of scenarios. Further the data should imply expectations in such a way that tests can be run in a random order and succeed reliably.

It would be useful to tie expectations to specific phone numbers similar to Twilio's test numbers. In order for tests to be reliably integrated with external services as needed, the phone numbers should correlate exactly with either a test number provided by Twilio or a number we've purchased that serves pre-determined TwiML consistently.

We can record incoming and outgoing rack requests using rack-recorder and webmock/vcr. The trick will be interleaving these such that an outgoing request stubbed by WebMock not only returns the request recorded by VCR but that it triggers an appropriate incoming request (mimicing the Twilio callback).

In order to interleve this sequence of requests a proxy (e.g. TwilioFake) can act as a stand-in for the real Twilio service. This proxy could be a sinatra app that runs standalone or mounted as an engine in test/development environments. The proxy will need access to the recordings from VCR and rack-recorder. The recordings should be presented to the proxy in a unified format such that the expected sequence of requests is maintained (and hopefully obvious when read by humans).

Joshua Wood gets us close with: http://joshuawood.net/record-inbound-rack-requests/. Rather than a standalone app recording and ignoring webhook requests, we need a proxy that will record an outgoing request/response and record the corresponding callback request/response. For replay, the proxy must then run the corresponding callback when the same outgoing request is made from the app. To closely mimic Twilio as an external service, the test environment should configure the app to use a localhost. The test environment must also boot the proxy. 

## Recording request sequences

### Outgoing requests

Can occur both within HTTP request cycles and via background jobs. There should be a consistent way to record both.

VCR provides a block taking method for wrapping requests made from calls in test suites. 
