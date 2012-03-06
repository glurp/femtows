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
require_relative "lib/femtows.rb"

Thread.abort_on_exception = false
BasicSocket.do_not_reverse_lookup = true

$ws=WebserverRoot.new(ARGV[0].to_i,".","femto ws",10,300, {})
$ws.serve("/info")    {|p|  
 [200,".html", "Femto demo<hr><a href='/'>site</a><hr>#{$ws.to_table(p)}" ] 
}

sleep

EEND
  
  
  s.files         = Dir['**/*']
  s.test_files    = Dir['samples/**'] 
  s.require_paths = ["lib"]
  
  
  ## Make sure you can build the gem on older versions of RubyGems too:
  s.rubygems_version = "1.8.15"
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.specification_version = 3 if s.respond_to? :specification_version
  
end

