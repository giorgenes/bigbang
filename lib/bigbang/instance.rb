module BigBang
	class Instance
		def initialize(name)
			@name = name
		end

		attr_accessor :ami, :key_name, :type, 
			:name,
			:bootstrap_repo,
			:bootstrap_params
	end
end
