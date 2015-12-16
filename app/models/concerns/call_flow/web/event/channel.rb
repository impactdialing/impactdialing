module CallFlow
  module Web
    class Event
      class Channel
        attr_reader :account_id
        include CallFlow::DialQueue::Util

        private
          def generate_name
            TokenGenerator.uuid
          end

          def key
            @key ||= "call_flow:web:event:channel:#{account_id}"
          end

          def _name
            @_name ||= redis.get(key)
          end

        public
          def initialize(account_id)
            if account_id.blank?
              raise CallFlow::BaseArgumentError, "Account ID is required"
            end
            @account_id = account_id
          end

          def name
            value = _name
            if value.blank?
              value = generate_name
              redis.set(key, value)
            end
            value
          end
      end
    end
  end
end
