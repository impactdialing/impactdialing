desc "Delete certain numbers from the database because don't wish to be called. This will be deprecated when we release the blocked numbers feature."

task :do_not_call => :environment do
  if ENV['NUMBERS'].blank?
    puts "Usage is 'rake do_not_call NUMBERS=\"1234567890 1115553333\"'"
  else
    numbers_to_remove = ENV['NUMBERS'].split(' ').map{|arg| arg.gsub(/[\(\)\+ -]/, '')}.select{|arg| arg.to_i != 0}
    missing_voters = []
    numbers_to_remove.each do |number|
      voters = Voter.find(:all, :conditions => ["Phone like '%%#{number}'"])
      if voters.empty?
        missing_voters << number
      else
        voters.each(&:destroy)
      end
    end
    puts "Couldn't find matches for #{missing_voters.join(', ')}"
  end
end
