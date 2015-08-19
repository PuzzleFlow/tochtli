require 'logger'

SEVERITIES = [:fatal] + [:error]*3 + [:warn]*5 + [:info]*12 + [:debug]*20

log = Logger.new('sample.log')

10000.times do 
	severity = SEVERITIES.sample
	log.send severity, "Sample #{severity}"
end

