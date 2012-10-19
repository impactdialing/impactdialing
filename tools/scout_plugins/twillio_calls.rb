
require 'set'

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
    report( calculate_report( retreive_output( generate_command() ) ) )
  rescue => error_message
    error "Couldn't parse output. Make sure you have proper SQL. #{error_message}"
  end

  private
  
  def generate_command
      # get_option returns nil if the option value is blank
      mysql    = 'mysql'
      user     = get_option(:user) || 'root'
      password = get_option(:password)
      host     = get_option(:host)
      port     = get_option(:port)
      socket   = get_option(:socket)
      database = get_option(:database)
      last_time = memory(:last_time) ? memory(:last_time) : Time.now.strftime("%Y-%m-%d %H:%M") 
      query    = "select count(id), created_at from calls where created_at > \"#{last_time}\" group by created_at"

      cmd = "#{mysql}"
      [:user, :password, :host, :port, :socket, :database].each do |option_name|
        cmd << " --#{option_name}='#{get_option(option_name)}'" if get_option(option_name)
      end
      cmd << " --execute='#{query}'"
    end

    def retreive_output(cmd)
      Open3.popen3(cmd) do |stdin, stdout, stderr|
        result = stdout.read
        
        error = stderr.gets        
        raise "#{error}\n for #{cmd}" if error
        
        if result.nil? || result.empty?
          remember(:last_time => Time.now.strftime("%Y-%m-%d %H:%M") )
          return []
        end

        return result
      end
    end
    
    def calculate_report(output)
      counts = []
      timestamps =[]
      report_hash = {}
      output.split("\n")[1..-1].each do |row|
        count, timestamp = row.split("\t")
        counts << count.to_i
        timestamps << timestamp
      end
      report_hash[:max_cps] = counts.max
      report_hash[:min_cps] = counts.min
      report_hash[:average_cps] = average(counts)
      report_hash[:mediana_cps] = mediana(counts)
      
      remember(:last_time => timestamps.max)
      report_hash
    end
        
    def average(arr)
      total = arr.inject(:+)
      len = arr.length
      average = total.to_f / len # to_f so we don't get an integer result
    end
    
    def mediana(arr)
      sortedarr = arr.sort 
      medpt1 = arr.length / 2
      medpt2 = (arr.length+1)/2
      (sortedarr[medpt1] + sortedarr[medpt2]).to_f / 2 
    end

    # Returns nil if an empty string
    def get_option(opt_name)
      val = option(opt_name)
      val = (val.is_a?(String) and val.strip == '') ? nil : val
      return val
    end

  end