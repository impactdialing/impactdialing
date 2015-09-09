shared_examples_for 'any call list import' do
  describe 'adding numbers to zsets' do
    context 'number is blocked' do
      before do
        parsed_households[phone].merge!({'blocked' => 1})
      end

      it 'adds to blocked zset' do
        subject.save(redis_keys, parsed_households)
        blocked_key = common_keys[5]
        expect(redis.zscore(blocked_key, phone)).to eq 1.0
      end

      it 'removes from available zset' do
        available_key = common_keys[3]
        redis.zadd available_key, 1.0, phone
        subject.save(redis_keys, parsed_households)
        expect(redis.zscore(available_key, phone)).to be_nil
      end

      it 'removes from recycle bin zset' do
        recycle_key = common_keys[4]
        redis.zadd recycle_key, 1.0, phone
        subject.save(redis_keys, parsed_households)
        expect(redis.zscore(recycle_key, phone)).to be_nil
      end
    end

    context 'number is not blocked' do
      before do
        parsed_households[phone].merge!({'blocked' => 0})
      end

      context 'number is not completed' do
        it 'adds to pending zset' do
          pending_key = common_keys[0]
          subject.save(redis_keys, parsed_households)
          expect(redis.zscore(pending_key, phone)).to_not be_nil
        end
      end

      context 'number is completed' do
        let(:completed_key){ common_keys[6] }
        let(:pending_key){ common_keys[0] }

        before do
          parsed_households[phone]['leads'][0].merge!({'custom_id' => 5})
          subject.save(redis_keys, parsed_households)
          redis.zrem(pending_key, phone)
          redis.zadd(completed_key, 2.2, phone)
        end


        context 'and 1 or more leads have been added' do
          before do
            parsed_households[phone]['leads'] << {
              'custom_id'  => 6,
              'first_name' => 'Marion'
            }
            subject.save(redis_keys, parsed_households)
          end

          it 'is removed from completed set' do
            expect(redis.zscore(common_keys[6], phone)).to be_nil
          end

          it 'is added to recycle bin set' do
            expect(redis.zscore(common_keys[4], phone)).to_not be_nil
          end
        end
      end
    end
  end
end
