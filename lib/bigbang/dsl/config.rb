module BigBang
	module DSL
		class Config
			attr_accessor :access_key_id, :secret_key, :dns_opts, :domain, :region
			def dns(d) @dns_opts = d; end
			
			def initialize
				self.region = "us-east-1"
			end
		end
	end
end
