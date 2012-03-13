# -*- encoding: utf-8 -*-
$:.push('lib')
require "ruiby/version"

Gem::Specification.new do |s|
  s.name     = "femtows"
  s.version  = File.read("VERSION").strip
  s.date     = Time.now.to_s.split(/\s+/)[0]
  s.email    = "regis.aubarede@gmail.com"
  s.homepage = "http://github.com/raubarede/femtows"
  s.authors  = ["Regis d'Aubarede"]
  s.summary  = "a tiny webserver"
  s.description = <<'EEND'
a tiny web server, for local file transfert, 
embededded, http experimentations
EEND
  
  
  s.files         = Dir['**/*']
  s.test_files    = Dir['samples/**'] 
  s.require_paths = ["lib"]
  s.executables   = `ls bin/*`.split("\n").map{ |f| File.basename(f) }  
  
  ## Make sure you can build the gem on older versions of RubyGems too:
  s.rubygems_version = "1.8.15"
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.specification_version = 3 if s.respond_to? :specification_version
  
end

