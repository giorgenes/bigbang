require 'base64'
require 'AWS'
require 'ap'
require 'set'
require 'fog'
require 'bigbang/provider'
require 'bigbang/dsl/dsl'
require 'bigbang/ec2-git-bootstrap'
require 'bigbang/kill'
require 'bigbang/test'
require 'bigbang/explode'

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

		def get_availability_zones
			item = provider.ec2.describe_availability_zones.availabilityZoneInfo.item
			item = [] if item.nil?
			item
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

		def get_instances_map
			map = {}
			get_instances.each do |i|
				map[i.instanceId] = i
			end
			map
		end

		def configured_elbs
			lbs = []
			@runs.each do |r|
				next unless r.is_a?(ClusterRun)
				next if r.lb.nil?
				lbs << r.lb
			end
			lbs
		end

		def get_addresses
			aset = provider.ec2.describe_addresses.addressesSet
			return [] if aset.nil?
			aset.item
		end
		
		def running_instances
			get_instances.find_all { |i| i.instanceState.name == "running" }
		end

		def running_instances_count(ids)
			running_instances.count { |i| ids.include?(i.instanceId) }
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

		def notify(msg)
			print "#{msg}: "
			STDOUT.flush
			begin
				r = yield
				puts "\033[01;32mOK\033[00m"
				return r
			rescue => e
				puts "\033[01;31mERROR\033[00m"
				raise
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

		include KillCmd
		include TestCmd
		include ExplodeCmd
	end
end
