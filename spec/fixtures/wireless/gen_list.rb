headers = ['NPS','NXX','X','Category','Future Use']

if ARGV[0] == 'block'
  # print headers
  STDOUT << "#{headers.join(',')}\n"
  # print rows
  600_000.times do
    STDOUT << [
      "#{rand(9)}#{rand(9)}#{rand(9)}",
      "#{rand(9)}#{rand(9)}#{rand(9)}",
      rand(9),
    ].join(',')
    STDOUT << "\n"
  end
else
  600_000.times do
    str = ''
    10.times{str<<"#{rand(9)}"}
    STDOUT << "#{str}\n"
  end
end