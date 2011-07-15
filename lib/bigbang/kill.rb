module BigBang
	module KillCmd
		def kill_instance(instance)
			confirm("kill instance #{instance.instanceId}") do
				provider.ec2.terminate_instances(:instance_id => [instance.instanceId])
				puts "sent termination signal to #{instance.instanceId}"
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
