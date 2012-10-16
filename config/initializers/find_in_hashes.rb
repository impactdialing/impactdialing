require Rails.root.join('lib/octopus_connection.rb')
require Rails.root.join("lib/batch_in_hashes.rb")
module ActiveRecord
  class Relation
    include BatchInHashes
  end
end
