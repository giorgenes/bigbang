require 'base64'
require 'AWS'
require 'ap'
require 'set'
require 'fog'
require 'bigbang/provider'
require 'bigbang/instance'
require 'bigbang/dsl'
require 'bigbang/ec2-git-bootstrap'

module BigBang
	class Universe
		def initialize(dsl)
			@instances = dsl.instances
			@runs = dsl.runs
			@config = dsl.conf
		end

		def provider
			return @provider unless @provider.nil?
			@provider = Provider.new(@config)
		end

		def get_instances
			rset = provider.ec2.describe_instances.reservationSet
			if rset.nil?
				return []
			else
				instances = []
				rset.item.each do |reservation|
					reservation.instancesSet.item.each do |i|
						instances << i
					end
				end
				return instances
			end
		end

		def get_addresses
			items = provider.ec2.describe_addresses.addressesSet.item
			items = [] if items.nil?
			items
		end
		
		def test
			get_instances	
			puts "ec2 access OK"
			@instances.collect { |i| i.ami }.to_set.each do |ami|
				begin
					provider.ec2.describe_images(:image_id => [ami])
				rescue AWS::InvalidAMIIDNotFound => e
					puts "ami #{ami} not found"
				end
			end
			puts "AMI's OK"
			if provider.configured_zone.nil?
				puts "Configured DNS domain zone not found"
			else
				puts "DNS domain OK"
			end
		end

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
				return
			end
			free_ips = provider.free_eips
			toalloc = runs.size
			blacklist = free_ips
			if free_ips.size > 0
				n = nil
				if free_ips.size >= runs.size
					n = runs.size
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
			(avail_ips - black_ips).to_a[0,runs.size]
		end

		def running_instances
			get_instances.find_all { |i| i.instanceState.name == "running" }
		end

		def running_instances_count(ids)
			running_instances.count { |i| ids.include?(i.instanceId) }
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

		def run_instances(name)
			instances = []
			gen = Ec2BootstrapGenerator.new
			@runs.each do |r|
				instance = r.instance
				userdata = Base64.encode64(gen.generate_from_hash(
					"bootstrap-repo" => instance.bootstrap_repo
				))
				res = provider.ec2.run_instances(
					:image_id => instance.ami,
					:key_name => instance.key_name,
					:instance_type => instance.type,
					:user_data => userdata)
				res.instancesSet.item.each do |i|
					instances << i
					provider.ec2.create_tags(:resource_id => i.instanceId,
						:tag => [
								{ 'bb_name' => instance.name },
								{ 'bb_universe' => name},
						])
				end
			end
			instances.tap do |i|
				wait_for_running(i)
			end
		end

		def assign_addresses(instances, addrs) 
			if instances.size != addrs.size
				raise "error: instances number and addresses don't match"
			end
	
			instances.each_index do |i|
				puts "associating address #{addrs[i]} " + 
					"to instance #{instances[i].instanceId}"
				provider.ec2.associate_address(
					:instance_id => instances[i].instanceId,
					:public_ip => addrs[i])
			end
		end

		def create_dns_entries(name, instances, addrs)
			@runs.each_index do |i|
				domains = [@runs[i].domain]
				if @runs[i].domain.is_a?(Array)
					domains = @runs[i].domain
				end
				domains.each do |domain|
					domain = "#{name}.#{domain}"
					puts "creating domain #{domain}.#{@config.domain} to #{addrs[i]}"
					provider.create_dns(domain, addrs[i])
					if @runs[i].wildcard_domain == true
						provider.create_dns("*.#{domain}", addrs[i])
					end
				end
			end
		end

		def explode(name)
			free_eips = allocate_addresses
			confirm("Will assign the following ips:\n" +
				"#{free_eips.join("\n")}\nConfirm") do
				instances = run_instances(name)
				assign_addresses(instances, free_eips)
				create_dns_entries(name, instances, free_eips)
			end
		end

		def get_tags
			tag_set = provider.ec2.describe_tags(:filter => 
					[{'key' => 'bb_universe'}]).tagSet
			if tag_set.nil?
				return []
			end

			tag_set.item
		end

		def list
			universes = Set.new
			get_tags.each do |tag|
				universes << tag.value
			end
		
			running = running_instances

			universes.each do |u|
				instances = universe_running_instances(running, universe_tags(u))
				if instances.empty?
					puts "#{u} (defunct)"
				else
					puts "#{u} (#{instances.size} running instances)"
				end
			end
		end

		def confirm(msg)
			print "#{msg}? [y/N] "
			if STDIN.gets.strip == "y"
				yield
				return true
			else
				puts "skipping"
				return false
			end
		end
		
		def kill_instance(instance)
			confirm("kill instance #{instance.instanceId}") do
				provider.ec2.terminate_instances(:instance_id => [instance.instanceId])
				puts "sent termination signal to #{instance.instanceId}"
			end
		end

		def instance_tags(tags = nil)
			tags = get_tags if tags.nil?
			tags.find_all { |t| t.resourceType == 'instance' }
		end

		def universe_running_instances(running, universe_tags)
			res = []
			instance_tags(universe_tags).each do |t|
				i = running.find { |i| i.instanceId == t.resourceId }
				res << i unless i.nil?
			end

			res
		end

		def universe_tags(name)
			get_tags.find_all do |tag|
				tag.value == name
			end
		end

		def kill_dns_entry(instance)
			records = provider.configured_zone.records

			records = records.find_all do |r|
				r.value == instance.ipAddress
			end
			if records.empty?
				puts "no DNS records found for ip #{instance.ipAddress}"
				return
			end

			domains = records.collect { |r| r.domain }
			confirm("Would you like to remove the following dns records?\n" +
				domains.join("\n") + "\n") do
				records.each do |r|
					puts "removing DNS #{r.domain}"
					r.destroy
				end
			end
		end

		def kill_eip(i, addresses)
			addr = addresses.find { |a| a.publicIp == i.ipAddress }
				
			unless addr.nil?
				confirm("Would you like to release EIP address #{addr.publicIp} of instance #{i.instanceId}") do
					puts "disassociating address #{addr.publicIp}"
					provider.ec2.disassociate_address(:public_ip => addr.publicIp)
					
					puts "releasing address #{addr.publicIp}"
					provider.ec2.release_address(:public_ip => addr.publicIp)
				end
			end
		end

		def kill(name)
			running = running_instances
			instances = universe_running_instances(running, universe_tags(name))
			addresses = get_addresses
			instances.each do |i|
				kill_dns_entry(i)
				kill_eip(i, addresses)
				kill_instance(i)
			end
		end
	end
end
