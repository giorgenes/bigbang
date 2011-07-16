require 'bigbang/run'
require 'bigbang/lb'

module BigBang
	class ClusterRun < Run
		attr_accessor :lb

		def initialize(name, instances)
			super(name, instances)
		end
	
		def availability_zone(h)
			@zone_sizes.merge!(h)
		end

		def load_balancer(name, &block)
			@lb = LoadBalancer.new(name)
			@lb.instance_eval(&block)
		end
	end
end
