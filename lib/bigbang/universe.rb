require 'lib/bigbang/provider'
require 'lib/bigbang/instance'
require 'lib/bigbang/dsl'
require 'AWS'
require 'ap'
require 'set'
require 'fog'

module BigBang
	class Universe
		def initialize
			@clusters = []
			@instances = []
		end

		include DSL
	
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

		def test
			ap provider.eips
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
			instances = @instances.find_all { |i| i.elastic_ip == true }
			if instances.empty?
				puts "no need to allocate elastic ips"
				return
			end
			free_ips = provider.free_eips
			toalloc = instances.size
			blacklist = free_ips
			if free_ips.size > 0
				n = nil
				if free_ips.size >= instances.size
					n = instances.size
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
			(avail_ips - black_ips).to_a[0,instances.size]
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
			@instances.each do |instance|
				res = provider.ec2.run_instances(
					:image_id => instance.ami,
					:key_name => instance.key_name,
					:instance_type => instance.type)
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
			@instances.each_index do |i|
				domains = [@instances[i].domain]
				if @instances[i].domain.is_a?(Array)
					domains = @instances[i].domain
				end
				domains.each do |domain|
					domain = "#{name}.#{@instances[i].domain}"
					puts "creating domain #{domain}.#{@config.domain} to #{addrs[i]}"
					provider.create_dns(domain, addrs[i])
					if @instances[i].wildcard_domain == true
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

		def tags
			tag_set = provider.ec2.describe_tags(:filter => 
					[{'key' => 'bb_universe'}]).tagSet
			if tag_set.nil?
				return []
			end

			tag_set.item
		end

		def list
			universes = Set.new
			tags.each do |tag|
				universes << tag.value
			end
			universes.each do |u|
				puts u
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
		
		def kill_instance(tag, running)
			instance = running.find { |i| i.instanceId == tag.resourceId }
			if instance.nil?
				puts "instance #{tag.resourceId} is not running. skipping"
				return
			end
			confirm("kill instance #{tag.resourceId}") do
				provider.ec2.terminate_instances(:instance_id => [tag.resourceId])
				puts "sent termination signal to #{tag.resourceId}"
			end
		end

		def kill(name)
			running = running_instances
			tags.find_all do |tag|
				tag.value == name
			end.each do |tag|
				send("kill_#{tag.resourceType}", tag, running)
			end
		end
	end
end
