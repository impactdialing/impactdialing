# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#   
#   cities = City.create([{ :name => 'Chicago' }, { :name => 'Copenhagen' }])
#   Major.create(:name => 'Daley', :city => cities.first)

module ImpactDialingSeeds
  def self.ask(q)
    print "#{q}: "
    fname = $stdin.gets.chomp
  end

  def self.initial_setup
    print "\nCreating an account and user. You will be asked for some info.\n"

    account = Account.create!({
      activated: true,
      tos_accepted_date: Time.now
    })

    admin = User.create!({
      active: true,
      role: 'admin',
      account: account,
      fname: ask('First name'),
      lname: ask('Last name'),
      email: ask('Email'),
      new_password: ask('Password')
    })
  end
end

ImpactDialingSeeds.initial_setup
