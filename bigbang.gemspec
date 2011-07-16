Gem::Specification.new do |s|
  s.name = %q{bigbang}
  s.version = "0.0.6"
  s.date = %q{2011-07-16}
  s.authors = ["Giorgenes Gelatti"]
  s.email = %q{giorgenes@gmail.com}
  s.summary = %q{A tool to bootstrap clusters of EC2 instances}
  s.homepage = %q{http://github.com/giorgenes/bigbang/}
  s.description = %q{}
  s.executables << "bigbang"
  s.files = Dir["src/*"] + Dir["bin/*"] + %w(README.rdoc lib/bigbang.rb) + 
		Dir["lib/bigbang/*"]
  s.extra_rdoc_files = ["README.rdoc"]
  s.rdoc_options = ["--main", "README.rdoc"]
  s.add_dependency('fog')
  s.add_dependency('amazon-ec2')
  s.require_paths = ["lib"]
end
