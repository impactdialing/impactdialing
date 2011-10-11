class CallAttemptResult < ActiveRecord::Migration
  def self.up
    add_column :call_attempts, :result, :string
    add_column :call_attempts, :result_digit, :string
    voters = Voter.all(:conditions=>"result is not null")
    voters.each do |voter|
      attempt = CallAttempt.find_by_voter_id(voter.id, :order=>"id desc", :limit=>1)
      if attempt!=nil
        attempt.result=voter.result
        attempt.result_digit = voter.result_digit
        attempt.save
      end
    end
  end

  def self.down
    remove_column :call_attempts, :result_digit
    remove_column :call_attempts, :result
  end
end
