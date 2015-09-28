require 'rails_helper'

describe 'ImportProxy' do
  before(:context) do
    ActiveRecord::Base.connection.create_table(:testers, force: true) do |t|
      t.column :name, :string
      t.column :email, :string
      t.timestamps
    end
    class Tester < ActiveRecord::Base
      extend ImportProxy

      validates_presence_of :name, :email
    end
  end

  after(:context) do
    ActiveRecord::Base.connection.drop_table(:testers)

    class Tester; end
  end

  let(:new_valid_testers) do
    [
      {name: 'John', email: 'john@test.com'},
      {name: 'Juan', email: 'juan@test.com'},
      {name: 'Sally', email: 'sally@test.com'}
    ]
  end
  let(:invalid_tester) do
    {name: '', email: '@test.com'}
  end

  describe '.import_hashes(hashes, options={})' do
    before do
      Tester.destroy_all
    end

    context 'creating new records (a hash in hashes that does not have an :id key is considered new)' do
      it 'creates a new record for each hash' do
        Tester.import_hashes(new_valid_testers)
        expect(Tester.count).to eq new_valid_testers.size
      end

      it 'updates rails timestamps for new records' do
        Timecop.freeze do
          Tester.import_hashes(new_valid_testers)
          expect(Tester.where(created_at: Time.now.utc).count).to eq new_valid_testers.size
          expect(Tester.where(updated_at: Time.now.utc).count).to eq new_valid_testers.size
        end
      end

      it 'does not create records for invalid data' do
        testers = new_valid_testers + [invalid_tester]
        Tester.import_hashes(testers)
        expect(Tester.count).to eq new_valid_testers.size
      end

      it 'will import invalid records when options[:validate] is false' do
        testers = new_valid_testers + [invalid_tester]
        Tester.import_hashes(testers, validate: false)
        expect(Tester.count).to eq new_valid_testers.size + 1
      end
    end

    context 'updating existing records (a hash in hashes that does have an :id key is considered existing)' do
      before do
        2.times do |i|
          Tester.create!(name: "Johnny", email: "johnny.#{i+4}.isalive@test.com")
        end
      end

      let(:existing_valid_testers) do
        a = []
        Tester.where(1).to_a.each do |tester|
          hash = tester.attributes
          hash['name'] = "#{hash['name']} #{tester.id}"
          a << hash
        end
        a
      end

      context 'when options[:columns_to_update] is not set or empty' do
        it 'updates each record identified by hash[:id]' do
          data = existing_valid_testers
          Tester.import_hashes(data)
          data.each do |hash|
            tester = Tester.find(hash['id'])
            expect(tester.name).to eq hash['name']
            expect(tester.email).to eq hash['email']
          end
        end

        it 'updates rails updated_at' do
          data = existing_valid_testers
          Timecop.freeze do
            Tester.import_hashes(data)
            expect(Tester.where(updated_at: Time.now.utc).count).to eq data.size
          end
        end

        it 'does not update with invalid data' do
          data = existing_valid_testers
          data[0] = data[0].merge(invalid_tester)
          Tester.import_hashes(data)
          tester_not_updated = Tester.find(data[0]['id'])
          expect(tester_not_updated.name).to_not eq invalid_tester[:name]
          expect(tester_not_updated.email).to_not eq invalid_tester[:email]
        end


        it 'will import invalid records when options[:validate] is false' do
          data = existing_valid_testers
          data[0] = data[0].merge(invalid_tester)
          Tester.import_hashes(data, validate: false)
          tester_not_updated = Tester.find(data[0]['id'])
          expect(tester_not_updated.name).to eq invalid_tester[:name]
          expect(tester_not_updated.email).to eq invalid_tester[:email]
        end
      end

      context 'when options[:columns_to_update] is set and not empty' do
        it 'does not update columns not declared in non-empty options[:columns_to_update]' do
          data = existing_valid_testers
          Tester.import_hashes(data, columns_to_update: [:email])
          data.each do |hash|
            tester = Tester.find(hash['id'])
            expect(tester.name).to_not eq hash['name']
            expect(tester.email).to eq hash['email']
          end
        end

        it 'updates columns declared in non-empty options[:columns_to_update]' do
          data = existing_valid_testers
          Tester.import_hashes(data, columns_to_update: [:name])
          data.each do |hash|
            tester = Tester.find(hash['id'])
            expect(tester.name).to eq hash['name']
            expect(tester.email).to eq hash['email']
          end
        end

        it 'always updates :updated_at' do
          data = existing_valid_testers
          Timecop.freeze do
            Tester.import_hashes(data, columns_to_update: [:email])
            expect(Tester.where(updated_at: Time.now.utc).count).to eq data.size
          end
        end
      end
    end
  end
end
