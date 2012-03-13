require_relative "lib/femtows.rb"

##################### mini log

$loggs= Queue.new
$file_log="femtows.log"
def logger(name="",adr="",*res) 
  mess= "%s | %-10s|%15s | %s" % [Time.now.strftime("%Y-%m-%d %H:%M:%S"),name,adr,res.join(" ")]
  ($loggs.size<1000) ? $loggs.push(mess) : puts(mess)
  true
end
Thread.new do
  loop do
     sleep 10
	 if $loggs.size>0
	  File.open($file_log,"a") { |f| f.puts( $loggs.pop ) while $loggs.size>0 }
	 end
  end
end

########################### main

Thread.abort_on_exception = false
BasicSocket.do_not_reverse_lookup = true

$ws=WebserverRoot.new(ARGV[0].to_i,".","femto ws",10,300, {
		"logg" => proc {|*par| logger(*par)  } 
})
$ws.serve("/info")    {|p|  
 [200,".html", "Femto demo<hr><a href='/'>site</a><hr>#{$ws.to_table(p)}" ] 
}

sleep
