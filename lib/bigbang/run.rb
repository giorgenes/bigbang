module BigBang
	class Run
		attr_accessor :instance, :domain, :wildcard_domain, :elastic_ip

		def initialize(name, instances)
			@instance = instances.find { |i| i.name == name }
			raise "instance #{name} not found" if @instance.nil?
		end
	end
end
