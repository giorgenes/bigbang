require 'bigbang/run'

module BigBang
	class ClusterRun < Run
	
		def initialize(name, instances)
			super(name, instances)
		end
	
		def availability_zone(h)
			@zone_sizes.merge!(h)
		end
	end
end
