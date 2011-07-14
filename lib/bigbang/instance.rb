module BigBang
	class Instance
		def initialize(name)
			@name = name
		end

		attr_accessor :ami, :key_name, :type, 
			:name, :elastic_ip, 
			:domain, :wildcard_domain,
			:bootstrap_repo,
			:bootstrap_params
	end
end