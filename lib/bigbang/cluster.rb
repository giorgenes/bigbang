require 'bigbang/instance'

module BigBang
	class Cluster < Instance
		def initialize(name)
			super(name)
		end
		attr_accessor :size
	end
end
