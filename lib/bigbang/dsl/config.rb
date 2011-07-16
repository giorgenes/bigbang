module BigBang
	module DSL
		class Config
			attr_accessor :access_key_id, :secret_key, :dns_opts, :domain
			def dns(d) @dns_opts = d; end
		end
	end
end
