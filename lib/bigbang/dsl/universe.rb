module BigBang
	module DSL
		class Universe
			attr_accessor :instances, :conf, :runs
			
			def initialize(&block)
				@instances = []
				@runs = []
				self.instance_eval(&block)
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

			def run_single_instance(name, &block)
				@runs << Run.new(name, @instances).tap do |r|
					r.instance_eval(&block)
				end
			end

			def run_cluster(name, &block)
				@runs << ClusterRun.new(name, @instances).tap do |r|
					r.instance_eval(&block)
				end
			end
		end
	end
end
