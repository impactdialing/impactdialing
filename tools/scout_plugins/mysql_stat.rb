require 'set'

class MysqlQueryStatistics < Scout::Plugin
  
  METADATA=<<-EOS_METADATA
    Com_select:
      label: Select Queries
      units: /sec
    Com_delete:
      label: Delete Queries
      units: /sec
    Com_update:
      label: Update Queries
      units: /sec
    Com_insert:
      label: Insert Queries
      units: /sec
    Com_replace:
      label: Replace Queries
      units: /sec
    total:
      label: Total Queries
      units: /sec
    Slow_queries:
      label: Slow Queries
      units: /sec
    Select_scan:
      label: Select Scan
      units: /sec
    Sort_rows:
      label: Sort Rows
      units: /sec
    Sort_scan:
      label: Sort scan
      units: /sec
    Created_tmp_disk_tables:
      label: Created tmp disk tables
      units: /sec
  EOS_METADATA
  
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
    socket:
      name: MySQL socket
      notes: Specify the location of the MySQL socket
    entries:
      name: Entries
      notes: 
      default: Com_insert Com_select Com_update Com_delete Slow_queries Select_scan Sort_rows Sort_scan Created_tmp_disk_tables
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
    query    = 'SHOW /*!50002 GLOBAL */ STATUS'

    # mysql = Mysql.connect(host, user, password, nil, (port.nil? ? nil : port.to_i), socket)
    # result = mysql.query('SHOW /*!50002 GLOBAL */ STATUS')
    cmd = "#{mysql}"
    [:user, :password, :host, :port, :socket].each do |option_name|
      cmd << " --#{option_name}='#{get_option(option_name)}'" if get_option(option_name)
    end
    cmd << " --execute='#{query}'"
  end

  def retreive_output(cmd)
    Open3.popen3(cmd) do |stdin, stdout, stderr|
      result = stdout.read
      
      raise "#{stderr.gets}\n for #{cmd}" unless result

      return result
    end
  end

  def calculate_report(output)
    report_hash = {}
    now = Time.now
    total = 0

    entries = get_option(:entries).to_s.split(' ').to_set
    output.split("\n")[1..-1].each do |row|
      name,value = row.split("\t")
      
      next unless entries.include?(name)
      value=value.to_i
      total += value if name[0..3] == 'Com_'
      value = calculate_counter(now, name, value)

      # only report if a value is calculated
      next unless value
      report_hash[name] = value
    end

    total_val = calculate_counter(now, 'total', total)
    
    
    report_hash['total'] = total_val if total_val 
    
    report_hash
  end

  # Returns nil if an empty string
  def get_option(opt_name)
    val = option(opt_name)
    val = (val.is_a?(String) and val.strip == '') ? nil : val
    return val
  end

  # Note this calculates the difference between the last run and the current run.
  def calculate_counter(current_time, name, value)
    result = nil
    # only check if a past run has a value for the specified query type
    if memory(name.to_sym) && memory(name.to_sym).is_a?(Hash)
      last_time, last_value = memory(name.to_sym).values_at(:time, :value)
      # We won't log it if the value has wrapped
      if last_value and value >= last_value
        elapsed_seconds = current_time - last_time
        elapsed_seconds = 1 if elapsed_seconds < 1
        result = value - last_value

        # calculate per-second
        result = result / elapsed_seconds.to_f
      end
    end
    remember(name.to_sym => {:time => current_time, :value => value})
    result
  end
end