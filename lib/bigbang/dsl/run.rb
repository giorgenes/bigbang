module BigBang
	module DSL
		class Run
			attr_accessor :instance, :domain, :wildcard_domain, :elastic_ip
			attr_accessor :zone_sizes
			attr_accessor :ec2_instances
			attr_accessor :assigned_ips

			def initialize(name, instances)
				@zone_sizes = {}
				@ec2_instances = []
				@assigned_ips = {}
				@instance = instances.find { |i| i.name == name }
				raise "instance #{name} not found" if @instance.nil?
			end

			def zones
				return @zone_sizes unless @zone_sizes.empty?

				{ nil => 1 }
			end

			def instances_count
				zones.values.inject(0) { |m,v| m += v }
			end
		end
	end
end
