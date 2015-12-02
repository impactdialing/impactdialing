RSpec::Matchers.define :instrument do |event|

  match do |actual|
    received_payload = {}
    ActiveSupport::Notifications.subscribe(event) do |name, start, finish, id, payload|
      received_payload = payload
    end

    klass, method_name = *actual[0..1]
    args = actual[2..-1]
    klass.send(method_name, *args)

    @payload.keys.all?{ |key| received_payload[key] == @payload[key] }
  end

  chain :with do |payload|
    @payload = payload
  end

  failure_message do |actual|
    "expected #{actual.join("\n")} to instrument #{event}"
  end
end
