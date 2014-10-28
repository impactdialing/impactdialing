headers = ['NPS','NXX','X','Category','Future Use']
lines = 
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
