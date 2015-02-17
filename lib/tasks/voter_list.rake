namespace :voter_list do
  desc "Seed all VoterList#households_count"
  task :seed_all_households_count => [:environment] do |t,args|
    report = []

    VoterList.find_in_batches(batch_size: 500) do |voter_lists|
      voter_lists.each do |voter_list|
        households_count = voter_list.voters.select('DISTINCT(household_id)').count
        voter_list.update_column(:households_count, households_count)

        report << [
          voter_list.id,
          voter_list.account_id,
          voter_list.campaign_id,
          voter_list.households_count,
          households_count
        ]
      end
    end

    print "VoterList ID, Account ID, Campaign ID, Cached households count, Expected households count\n"
    print report.map{|r| r.join(',')}.join("\n") + "\n"
  end

  desc "Report all VoterList#households_count"
  task :report_all_households_count => [:environment] do |t,args|
    report = []

    VoterList.find_in_batches(batch_size: 500) do |voter_lists|
      voter_lists.each do |voter_list|
        report << [
          voter_list.id,
          voter_list.account_id,
          voter_list.campaign_id,
          voter_list.households_count
        ]
      end
    end

    print "VoterList ID, Account ID, Campaign ID, Cached households count\n"
    print report.map{|r| r.join(',')}.join("\n") + "\n"
  end
end
