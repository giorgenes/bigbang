Gem::Specification.new do |s|
  s.name = %q{bigbang}
  s.version = "0.0.1"
  s.date = %q{2011-07-15}
  s.authors = ["Giorgenes Gelatti"]
  s.email = %q{giorgenes@gmail.com}
  s.summary = %q{}
  s.homepage = %q{http://github.com/giorgenes/bigbang/}
  s.description = %q{}
  s.executables << "bigbang"
  s.files = Dir["src/*"] + Dir["bin/*"] + ["README"] + Dir["lib/bigbang.rb"] + 
		Dir["lib/bigbang/*"]
  s.add_dependency('fog')
  s.add_dependency('amazon-ec2')
  s.require_paths = ["lib"]
end
