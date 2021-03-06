module BigBang
	class Provider
		def initialize(config)
			@config = config
		end

		def aws_server_config
			{
				:access_key_id => @config.access_key_id, 
				:secret_access_key => @config.secret_key,
			}
		end
		
		def elb_server_config
			aws_server_config.merge(
				:server => "elasticloadbalancing.#{@config.region}.amazonaws.com")
		end

		def ec2_server_config
			aws_server_config.merge(
				:server => "ec2.#{@config.region}.amazonaws.com")
		end

		def ec2
			return @ec2 unless @ec2.nil?
			@ec2 = AWS::EC2::Base.new(ec2_server_config)
		end

		def elb
			return @elb unless @elb.nil?
			@elb = AWS::ELB::Base.new(elb_server_config)
		end

		def dns
			return @dns unless @dns.nil?
			@dns = Fog::DNS.new(@config.dns_opts)
		end

		def configured_zone
			dns.zones.find { |z| z.domain == @config.domain }
		end

		def create_dns(domain, value, type)
				configured_zone.records.create(
						:value => value,
						:name => domain,
						:type => type)
		end
		
		def eips
			aset = ec2.describe_addresses.addressesSet
			if aset.nil?
				return []
			else
				return aset.item
			end
		end

		def free_eips
			eips.find_all { |eip| eip.instanceId.nil? }
		end
	end
end
