module BigBang
	module TestCmd
		def test_availability_zones
			zones = Set.new
			@runs.each do |r|
				r.zone_sizes.each_key do |k|
					zones << k
				end
			end

			return if zones.empty?
			ec2_zones = get_availability_zones
			zones.each do |zone|
				unless ec2_zones.find { |z| z.zoneName == zone}
					raise "zone '#{zone}' not found"
				end
			end

			puts "Availability zones OK"
		end

		def test_amis
			@instances.collect { |i| i.ami }.to_set.each do |ami|
				begin
					provider.ec2.describe_images(:image_id => [ami])
				rescue AWS::InvalidAMIIDNotFound => e
					puts "ami #{ami} not found"
				end
			end
			puts "AMI's OK"
		end

		def test_dns
			if provider.configured_zone.nil?
				puts "Configured DNS domain zone not found"
			else
				puts "DNS domain OK"
			end
		end

		def test_elb
			ap provider.elb.describe_load_balancers
			puts "elb access OK"
		end

		def test
			get_instances
			puts "ec2 access OK"

			test_elb
			test_availability_zones
			test_amis
			test_dns
		end
	end
end
