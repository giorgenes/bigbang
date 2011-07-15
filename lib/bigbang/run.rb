module BigBang
	class Run
		attr_accessor :instance, :domain, :wildcard_domain, :elastic_ip
		attr_accessor :zone_sizes

		def initialize(name, instances)
			@zone_sizes = {}
			@instance = instances.find { |i| i.name == name }
			raise "instance #{name} not found" if @instance.nil?
		end
	end
end
