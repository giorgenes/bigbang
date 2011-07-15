module BigBang
	module ExplodeCmd
		def wait_for_eips(expected)
			print "waiting for eips to be allocated"
			STDOUT.flush
			addrs = provider.free_eips
			while(addrs.size < expected)
				sleep(1)
				print "."
				STDOUT.flush
				addrs = provider.free_eips
			end
			puts
			addrs
		end

		def allocate_addresses
			runs = @runs.find_all { |r| r.elastic_ip == true }
			if runs.empty?
				puts "no need to allocate elastic ips"
				return []
			end
			free_ips = provider.free_eips
			ninstances = runs.inject(0) { |m,r| m += r.instances_count }
			toalloc = ninstances 
			blacklist = free_ips
			if free_ips.size > 0
				n = nil
				if free_ips.size >= ninstances
					n = ninstances
				else
					n = free_ips.size
				end
				confirm("Use #{n} of your #{free_ips.size} free eips?") do
					blacklist = []
					toalloc -= n
				end
			end
			puts "need to alloc: #{toalloc}"
			1.upto(toalloc) do |i|
				puts "allocating eip address #{i}"
				provider.ec2.allocate_address
			end

			addrs = wait_for_eips(free_ips.size + toalloc)
			avail_ips = addrs.collect { |a| a.publicIp }.to_set
			black_ips = blacklist.collect { |a| a.publicIp }.to_set
			(avail_ips - black_ips).to_a[0,ninstances]
		end



		def wait_for_running(instances)
			ids = instances.collect { |i| i.instanceId }.to_set
			print "Waiting for all instances to be in running state. "
			STDOUT.flush
			while running_instances_count(ids) < instances.size
				print "."
				sleep(5)
				STDOUT.flush
			end
			puts
		end

		def tag_instance(instance, ec2_instance, name)
			provider.ec2.create_tags(:resource_id => ec2_instance.instanceId,
					:tag => [
							{ 'bb_name' => instance.name },
							{ 'bb_universe' => name},
					])
		end

		def run_instance(instance, userdata, zone, size)
			puts "launching #{size} instance(s) on availability zone '#{zone}'"
			provider.ec2.run_instances(
					:image_id => instance.ami,
					:key_name => instance.key_name,
					:instance_type => instance.type,
					:user_data => userdata,
					:availability_zone => zone,
					:min_count => size,
					:max_count => size
			)
		end

		def run_instances(name)
			instances = []
			gen = Ec2BootstrapGenerator.new
			@runs.each do |r|
				instance = r.instance
				userdata = Base64.encode64(gen.generate_from_hash(
					"bootstrap-repo" => instance.bootstrap_repo
				))
				r.zones.each_pair do |zone,size|
					res = run_instance(instance, userdata, zone, size)
					res.instancesSet.item.each do |i|
						instances << i
						r.ec2_instances << i.instanceId
						tag_instance(instance, i, name)
					end
				end
			end
			wait_for_running(instances)
		end

		def assign_addresses(addrs) 
			@runs.each do |r|
				r.ec2_instances.each do |instance|
					addr = addrs.pop
					puts "associating address #{addr} " + 
						"to instance #{instance.instanceId}"
					provider.ec2.associate_address(
						:instance_id => instance.instanceId,
						:public_ip => addr)
					r.assigned_ips[instance.instanceId] = addr
				end
			end
		end

		def create_dns_entry_for(instance, universe_name, domain, addr, wildcard)
			domain = "#{universe_name}.#{domain}"
			puts "creating domain #{domain}.#{@config.domain} to #{addr}"
			provider.create_dns(domain, addr)
			if wildcard == true
				provider.create_dns("*.#{domain}", addr)
			end
		end

		def create_dns_entries(universe_name)
			instances_map = get_instances_map
			@runs.each do |r|
				addsufix = false
				if r.is_a?(ClusterRun)
					addsufix = true
				end

				domains = [r.domain]
				if r.domain.is_a?(Array)
					domains = r.domain
				end

				sufix = 0
				r.ec2_instances.each do |instance_id|
					instance = instances_map[instance_id]
					domains.each do |domain|
						addr = r.assigned_ips[instance.instanceId]
						# use the elastic ip
						if addr.nil?
							addr = instance.ipAddress
						end

						if addsufix
							domain = "#{domain}#{sufix}"
						end
						create_dns_entry_for(instance, universe_name, domain, addr, r.wildcard_domain)
					end
					sufix += 1
				end
			end
		end

		def explode(name)
			free_eips = allocate_addresses
			run_instances(name)
			unless free_eips.empty?
				confirm("Will assign the following ips:\n" +
					"#{free_eips.join("\n")}\nConfirm") do
					assign_addresses(free_eips)
				end
			end
			create_dns_entries(name)
		end
	end
end
