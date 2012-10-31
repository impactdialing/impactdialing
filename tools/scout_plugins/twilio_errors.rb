
require 'set'
require 'rubygems'
require 'active_record'
require 'mysql2'
require 'twilio-ruby'


class Notification < ActiveRecord::Base
end

class MysqlQueryStatistics < Scout::Plugin
  
  # An embedded YAML doc describing the options this plugin takes
  OPTIONS=<<-EOS
    user:
      name: MySQL username
      notes: Specify the username to connect with
      default: root
    password:
      name: MySQL password
      notes: Specify the password to connect with
    host:
      name: MySQL host
      notes: Specify something other than 'localhost' to connect via TCP
      default: localhost
    port:
      name: MySQL port
      notes: Specify the port to connect to MySQL with (if nonstandard)
    database:
      name: MySQL database
      notes: Specify the database name to connect to MySQL with (if nonstandard)
    socket:
      name: MySQL socket
      notes: Specify the location of the MySQL socket
  EOS
  
  # needs "mysql"
  needs "open3"

  def build_report
    ActiveRecord::Base.establish_connection(adapter: 'mysql2', 
                                            database: 'twilio_logs',
                                            host: "twilio-logs.cjo94dhm4pos.us-east-1.rds.amazonaws.com",
                                            username: "root",
                                            password: "mypassword912481")
    
    @account_sid = 'AC422d17e57a30598f8120ee67feae29cd'
    @auth_token = '897298ab9f34357f651895a7011e1631' 

    # set up a client to talk to the Twilio REST API
    @client = Twilio::REST::Client.new(@account_sid, @auth_token)

    @account = @client.account

    date = (Time.now.utc.to_date - 2.day).to_s
    puts date
    page = memory(:last_page) || 0
    while !fetch_chunk(date, page).empty?
      remember(:last_page => page)          
      page = page + 1
      puts "fetched page #{page}"
    end                         
    #report( calculate_report( retreive_output( generate_command() ) ) )
 # rescue => error_message
#    error "Couldn't parse output. #{error_message}"
  end 
  
  
  
  def fetch_chunk(date, page)
    puts "fetching"
    @account.notifications.list({:message_date => date, :page_size => '100', :page => page}).each do |x|
      puts x.date_updated
      n = Notification.where(sid: x.sid).first || Notification.new
      n.sid = x.sid
      n.account_sid = x.account_sid
      n.call_sid = x.call_sid
      n.log = x.log
      n.error_code = x.error_code
      n.more_info = x.more_info
      n.message_text = x.message_text
      n.message_date = x.message_date
      n.response_body = x.response_body if x.respond_to?(:response_body)
      n.request_method = x.request_method
      n.request_url = x.request_url
      n.date_updated = x.date_updated
      n.save
    end
  end

  end