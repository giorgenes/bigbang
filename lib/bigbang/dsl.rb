require 'bigbang/config'
require 'bigbang/instance'
require 'bigbang/cluster'

module BigBang
	class DSL
		attr_accessor :instances, :conf
		
		def initialize
			@instances = []
		end

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
			@conf = Config.new.tap do |c|
				c.instance_eval(&block)
			end
		end
	end
end
