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
		end

		def test_amis
			@instances.collect { |i| i.ami }.to_set.each do |ami|
				begin
					provider.ec2.describe_images(:image_id => [ami])
				rescue AWS::InvalidAMIIDNotFound => e
					raise "ami #{ami} not found"
				end
			end
		end

		def test_dns
			if provider.configured_zone.nil?
				raise "Configured DNS domain zone not found"
			end
		end

		def test
			notify("Testing EC2 access") do
				get_instances
			end

			notify("Testing configured availability zones") do
				test_availability_zones
			end

			notify("Testing configured AMI's") do
				test_amis
			end
	
			notify("Testing DNS API access") do
				test_dns
			end
		end
	end
end
