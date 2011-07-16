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
			notify("Waiting for all instances to be in running state. ") do
				while running_instances_count(ids) < instances.size
					print "."
					STDOUT.flush
					sleep(5)
				end
			end
		end

		def tag_instance(instance, ec2_instance, name)
			provider.ec2.create_tags(:resource_id => ec2_instance.instanceId,
					:tag => [
							{ 'bb_name' => instance.name },
							{ 'bb_universe' => name},
					])
		end

		def run_instance(instance, userdata, zone, size)
			notify("launching #{size} instance(s) on availability zone '#{zone}'") do
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

		def dns_entry_for(instance, universe_name, domain, addr, wildcard)
			entries = []
			domain = "#{universe_name}.#{domain}"
			entries << {:domain => domain, :value => addr, :type => 'A'}
			if wildcard == true
				entries << {:domain => "*.#{domain}", :value => addr, :type => 'A'}
			end
			entries
		end

		def create_dns_entries(entries)
			entries.each do |entry|
				notify("creating domain #{entry[:domain]}.#{@config.domain} => #{entry[:value]}") do
					provider.create_dns(entry[:domain], entry[:value], entry[:type])
				end
			end
		end

		def instance_dns_entries(universe_name)
			entries = []
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
						entries += dns_entry_for(instance, universe_name, domain, addr, r.wildcard_domain)
					end
					sufix += 1
				end
			end
			entries
		end

		def create_lb(lb)
			p = notify("creating ELB #{lb.name}") do
				provider.elb.create_load_balancer(
					:load_balancer_name => lb.name,
					:listeners => lb.listeners,
					:availability_zones => lb.availability_zones)
			end
			p
		end

		def create_load_balancers
			@runs.each do |r|
				next unless r.is_a?(ClusterRun)
				next if r.lb.nil?

				r.lb.ec2_elb = create_lb(r.lb)

				notify("registering instances to ELB #{r.lb.name}") do
					provider.elb.register_instances_with_load_balancer(
						:load_balancer_name => r.lb.name,
						:instances => r.ec2_instances
					)
				end
			end
		end

		def elb_dns_entries(universe_name)
			entries = []
			configured_elbs.each do |lb|
				lb.domains.each do |domain|
					subdomain = "#{universe_name}.#{domain}"
					cname = lb.ec2_elb.CreateLoadBalancerResult.DNSName
					entries << { :domain => subdomain, :value => cname, :type => "CNAME" }
				end
			end
			entries
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
			create_load_balancers
			dns_entries = elb_dns_entries(name)
			dns_entries += instance_dns_entries(name)
			create_dns_entries(dns_entries)
		end
	end
end
