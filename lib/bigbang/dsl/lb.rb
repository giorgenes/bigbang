module BigBang
	module DSL
		class LoadBalancer
			attr_accessor :domains, :name, :listeners, :availability_zones
			attr_accessor :ec2_elb

			def initialize(name)
				@name = name
			end
		end
	end
end
