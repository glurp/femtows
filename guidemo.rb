#require_relative "lib/femtows.rb"
#require_relative '../../Ruiby/lib/ruiby.rb'
require 'femtows'
require 'ruiby'

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
			}
			@logt= slot(text_area(800,160,{font: "courier new 8"})).children[0]
			sloti(button("reset log") { @logt.buffer.text="resetted" })
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
		@logt.buffer.text+=mess 
		if @logt.buffer.text.size>1000*1000
		  @logt.buffer.text=@logt.buffer.text[10*1000..-1]
		end
	end
end
def deflog(name,adr,*res) 
		mess= "%s |%15s | %s\n" % [Time.now.strftime("%Y-%m-%d %H:%M:%S"),adr,res.join(" ")]
		gui_invoke { logs(mess) rescue print $!.to_s+" "+mess}
end


########################### main
Thread.abort_on_exception = false
BasicSocket.do_not_reverse_lookup = true
Ruiby.start { Server.new("Web server",800,200).run_server }