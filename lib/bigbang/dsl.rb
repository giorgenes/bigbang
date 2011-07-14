require 'lib/bigbang/config'
require 'lib/bigbang/instance'
require 'lib/bigbang/cluster'

module BigBang
	module DSL
		def cluster(name, &block)
			@instances << Cluster.new(name).tap do |cluster|
				cluster.instance_eval(&block)
			end
		end
		
		def instance(name, &block)
			@instances << Instance.new(name).tap do |i|
				i.instance_eval(&block)
			end
		end

		def config(&block)
			@config = Config.new.tap do |c|
				c.instance_eval(&block)
			end
		end
	end
end
