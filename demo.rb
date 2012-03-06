require_relative "lib/femtows.rb"


Thread.abort_on_exception = false
BasicSocket.do_not_reverse_lookup = true

$ws=WebserverRoot.new(ARGV[0].to_i,".","femto ws",10,300, {})
$ws.serve("/info")    {|p|  
 [200,".html", "Femto demo<hr><a href='/'>site</a><hr>#{$ws.to_table(p)}" ] 
}

sleep
