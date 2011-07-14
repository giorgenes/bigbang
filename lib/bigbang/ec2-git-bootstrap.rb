class Ec2BootstrapGenerator
	def generate_from_dir(path)
		basedir = File.dirname(__FILE__) + "/../../"
		tmp=%x(mktemp -d /tmp/gen-ec2-userdata.XXXXX).strip
		%x(mkdir -p #{tmp}/data)
		%x(cp -r #{path}/* #{tmp}/data/)
		%x(cp #{basedir}/src/* #{tmp})
		tmptar=%x(mktemp /tmp/gen-ec2-userdata.XXXXX.tar.gz).strip
		%x(tar -czf #{tmptar} -C #{tmp} .)

		File.new("#{basedir}/src/bootstrap.sh").read +
			File.new(tmptar).read
	end

	def generate_from_hash(h)
		tmp=%x(mktemp -d /tmp/gen-ec2-userdata.XXXXX).strip
		h.each_pair do |k,v|
			f = File.new("#{tmp}/#{k}", "w")
			f.write(v)
			f.close
		end

		generate_from_dir(tmp).tap do |r|
			%x(rm -fr #{tmp})
		end
	end
end
