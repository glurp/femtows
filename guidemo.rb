#require_relative '../../Ruiby/lib/ruiby.rb'
#require_relative "lib/femtows.rb"
require 'ruiby'
require 'femtows'

ruiby_require 'erubis','xxx'

class Server < Ruiby_gtk
	def initialize(t,w,h)
		$server=self
		@port=8100
		@root="/"
		super
		threader(50)
	end
	def component
		stack {
			flowi {
				table(2,2) {
					row { cell_right label("root") ; cell(@eroot=entry(@root)) }
					row { cell_right label("port") ; cell(@eport=ientry(@port,:min=>0,:max=>65535,:by=>10)) }
				}
				button("Restart") { 
					@root,@port=@eroot.text,@eport.text.to_i
					$ws.stop_browser if $ws
					run_server
					deflog("","","restart ok")
				}
				button("reset log") { @logt.text="resetted\n" }
			}
			@logt= slot(text_area(800,160,{font: "courier new 8"}))
		}
	end
	def run_server
		after(1) do
		begin
			$ws=WebserverRoot.new(@port,@root,"femto ws",10,300, {
					"logg" => proc {|*par| deflog(*par) } 
			})
			$ws.serve("/info")    {|p|  
			 [200,".html", "Femto demo<hr><a href='/'>site</a><hr>#{$ws.to_table(p)}" ] 
			}
			deflog('','',"restarted!")
		rescue
			deflog(["","",$!.to_s])
		end
		end
	end
	def logs(mess)
		@logt.append(mess)
		if @logt.text.size>100*1000
		  @logt.text=@logt.text[500..-1]
		end
	end
end
def deflog(name,adr,*res) 
		mess= "%s |%15s | %s\n" % [Time.now.strftime("%Y-%m-%d %H:%M:%S"),adr,res.join(" ")]
		gui_invoke { logs(mess) rescue print $!.to_s+ $!.backtrace.join("\n")+"\n /// "+mess}
end


########################### main
Thread.abort_on_exception = false
BasicSocket.do_not_reverse_lookup = true
Ruiby.start { Server.new("Web server",800,200).run_server }