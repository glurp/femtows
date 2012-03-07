# FemtoWebServer : 232 LOC web server
#
#   $ws=WebserverRoot.new(port,"/home/www","femto ws",10,300)
#   ws.serve "/FOO" do |params|
#      data=params["HEAD-DATA"]|| ""
#      puts "Recu data len=#{data.length} : <#{data[0..1000]}>" if data
#      [200,".json",""]
# end
  
  
require 'thread'
require 'socket'
require 'timeout'

#################### Tiny embeded webserver
class WebserverAbstract
  def logg(*args)  @cb_log && @cb_log.call(@name,*args) end
  def info(txt) ; logg("nw>i>",txt) ;  end
  def error(txt) ; logg("nw>e>",txt) ; end
  def unescape(string) ; string.tr('+', ' ').gsub(/((?:%[0-9a-fA-F]{2}))/n) { [$1.delete('%')].pack('H*') } ;  end
  def escape(string) ; string.gsub(/([^ \/a-zA-Z0-9_.-]+)/) { '%' + $1.unpack('H2' * $1.size).join('%').upcase }.tr(' ', '+');  end
  def hescape(string) ;  escape(string.gsub("/./","/").gsub("//","/")) ; end
  def observe(sleeping,delta)
	@tho=Thread.new do loop do
	  sleep(sleeping) 
	  nowDelta=Time.now-delta
	  l=@th.select { |th,tm| (tm[0]<nowDelta) }
	  l.each { |th,tm| info("killing thread") ; th.kill; @th.delete(th)  ; tm[1].close rescue nil }
	end ; end
  end
  def initialize(port,root,name,cadence,timeout,options)
    @cb_log= options["logg"] 
    @last_mtime=File.mtime(__FILE__)
	@port=port
	@root=root
	@name=name
	@rootd=root[-1,1]=="/" ? root : root+"/" 
	@timeout=timeout
	@th={}
	@cb={}
	@redirect={}
	info(" serveur http #{port} on #{@rootd} ready!")
	observe(cadence,timeout*2)
	@thm=Thread.new { 
		loop { 
			nbError=0
			begin
				session=nil
				@server = TCPServer.new('0.0.0.0', @port)
				@server.setsockopt(Socket::SOL_SOCKET,Socket::SO_REUSEADDR, true)
				while (session = @server.accept)
					nbError=0
					run(session)
				end
			rescue Exception => e
			  nbError+=1
			  error($!.to_s + "  " + $!.backtrace[0..2].join(" "))
			  session.close rescue nil
			  @server.close rescue nil
			end
			(error("too much error consecutive");exit!(0)) if nbError>3
			sleep(3); info("restart accept")
		}
	}
  end
  def run(session)
	if ! File.exists?(@root)
	  sendError(session,500,txt="root directory unknown: #{@root}") rescue nil
	  session.close rescue nil
	else
		Thread.new(session) do |sess|
		   @th[Thread.current]=[Time.now,sess]
		   request(sess) 
		   @th.delete(Thread.current) 
		end
	end
  end
  def serve(uri,&blk)
	@cb[uri] = blk
  end  
  def request(session)
	  request = session.gets
	  uri = (request.split(/\s+/)+['','',''])[1] 
      logg(session.peeraddr.last,request.chomp+ " ...") 
	  #info uri
	  service,param,*bidon=(uri+"?").split(/\?/)
	  params=Hash[*(param.split(/#/)[0].split(/[=&]/))] rescue {}
	  params.each { |k,v| params[k]=unescape(v) }
	  uri=unescape(service)[1..-1].gsub(/\.\./,"")
	  userpass=nil
	  if (buri=uri.split(/@/)).size>1
		uri=buri[1..-1].join("@")
		userpass=buri[0].split(/:/)
	  end
	  read_header(session,params)
	  do_service(session,request,uri,userpass,params)
      logg(session.peeraddr.last,request.chomp + " ... ok") 
  rescue Exception => e
	error("Error Web get on #{request}: \n #{$!.to_s} \n #{$!.backtrace.join("\n     ")}" ) rescue nil
	session.write "HTTP/1.0 501 NOK\r\nContent-type: text/html\r\n\r\n<html><head><title>WS</title></head><body>Error : #{$!}" rescue nil
  ensure
	session.close rescue nil
  end  
  def read_header(session,params)
	timeout(120) do
	   head=session.gets("\r\n\r\n")
	   head.split(/\r\n/m).each { |line| name,data=line.split(": ",2) ; params["HEAD-"+name.upcase]=data }
	   if params["HEAD-CONTENT-LENGTH"]
			len= params["HEAD-CONTENT-LENGTH"].split(/\s+/).last.to_i
			params["HEAD-CONTENT-LENGTH"]=len
			data=""
			while len>0
				d=session.read(len>64*1024 ? 64*1024 : len)
				raise("closed") if !d
				len -= d.length
				data+=d
			end	
		    params["HEAD-DATA"]=data
	   end
	end
  end
  
  def redirect(o,d)
   @redirect[o]=d
  end  
  def do_service(session,request,service,user_passwd,params)
    logg(session.peeraddr.last,request.chomp) 
	redir=@redirect["/"+service]
	service=redir.gsub(/^\//,"") if @redirect[redir]
	aservice=to_absolute(service)
	if redir &&  ! @redirect[redir] 
	  do_service(session,request,redir.gsub(/^\//,""),user_passwd,params)
	elsif @cb["/"+service]
	  begin
	   code,type,data= @cb["/"+service].call(params)
	   if code==0 && data != '/'+service
		  do_service(session,request,data[1..-1],user_passwd,params)
	   else
		 code==200 ?  sendData(session,type,data) : sendError(session,code,data)
	   end
	  rescue
	   logg session.peeraddr.last,"Error in get /#{service} : #{$!}"
	   sendError(session,501,$!.to_s)
	  end
	elsif service =~ /^stop/ 
	  sendData(session,".html","Stopping...");	   
	  Thread.new() { sleep(0.1); stop_browser()  }
	elsif File.directory?(aservice)
	  sendData(session,".html",makeIndex(aservice))
	elsif File.exists?(aservice)
	  sendFile(session,aservice)
	else
	  info("unknown request serv=#{service} params=#{params.inspect} #{File.exists?(service)}")
	  sendError(session,500,"unknown request serv=#{aservice} params=#{params.inspect} #{File.exists?(service)}");
	end
  end
  def stop_browser
	info "exit on web demand !"
	@serveur.close rescue nil
	[@tho,@thm].each { |th| th.kill }
  end
  def makeIndex(adir)
    dir=to_relative(adir)
	dirs,files=Dir.glob(adir==@rootd ? "#{@rootd}*" : "#{adir}/*").sort.partition { |f| File.directory?(f)}

	updir = hescape(  dir.split(/\//)[0..-2].join("/")) 
	updir="/" if updir.length==0
	up=(dir!="/") ? "<input type='button' onclick='location.href=\"#{updir}\"' value='Parent'>" : ""
	"<html><head><title>#{dir}</title></head>\n<body><h3><center>#{@name} : #{dir[0..-1]}</center></h3>\n<hr>#{up}<br>#{to_table(dirs.map {|s| " <a href='#{hescape(to_relative(s))}'>"+File.basename(s)+"/"+"</a>\n"})}<hr>#{to_tableb(files) {|f| [" <a href='#{hescape(to_relative(f))}'>"+File.basename(f)+"</a>",n3(File.size(f)),File.mtime(f).strftime("%d/%m/%Y %H:%M:%S")]}}</body></html>"
  end  
  def to_relative(f)  f.gsub(/^#{@rootd}/,"/") end
  def to_absolute(f)  "#{@rootd}#{f.gsub(/^\//,'')}" end
  def n3(n)
     u=" B"
     if n> 10000000
	    n=n/(1024*1024)
		u=" MB"
     elsif n> 100000
	    n=n/1024
		u=" KB"
	 end
    "<div style='width:100px;text-align:right;'>#{(n.round.to_i.to_s.reverse.gsub(/(\d\d\d)(?=\d)/,'\1 ' ).reverse) +u} | </div>"
  end
  def to_table(l)
	 "<table><tr>#{l.map {|s| "<td>#{s}</td>"}.join("</tr><tr>")}</tr></table>"
  end 
  def to_tableb(l,&bl)
	 "<table><tr>#{l.map {|s| "<td>#{bl.call(s).join("</td><td>")}</td>"}.join("</tr><tr>")}</tr></table>"
  end 
  def sendError(sock,no,txt=nil) 
	 if txt
	   txt="<html><body><code><pre></pre>#{txt}</code></body></html>"
	 end
	sock.write "HTTP/1.0 #{no} NOK\r\nContent-type: #{mime(".html")}\r\n\r\n <html><p>Error #{no} : #{txt}</p></html>"
  end
  def sendData(sock,type,content)
	sock.write "HTTP/1.0 200 OK\r\nContent-Type: #{mime(type)}\r\nContent-Length: #{content.size}\r\n\r\n"
	sock.write(content)
  end
  def sendFile(sock,filename)
  	s=File.size(filename)
  	if s < 0 || s>60_000_000 || File.extname(filename).downcase==".lnk"
		logg @name,"Error reading file/File not downloadable  #{File.basename(filename)} : (size=#{s})"
  		sendError(sock,500,"Error reading file/File not downloadable  #{filename} : (size=#{s})" )
  		return
  	end
	logg @name,filename," #{s/(1024*1024)} Mo" if s>10*1000_000
	timeout([s/(512*1024),30.0].max.to_i) {
		sock.write "HTTP/1.0 200 OK\r\nContent-Type: #{mime(filename)}\r\nContent-Length: #{File.size(filename)}\r\nLast-Modified: #{httpdate(File.mtime(filename))}\r\nDate: #{httpdate(Time.now)}\r\n\r\n"
		File.open(filename,"rb") do |f| 
		  f.binmode; sock.binmode; 
		  ( sock.write(f.read(32*1024)) while (! f.eof? && ! sock.closed?) ) rescue nil
		end
	} 
  end
  def httpdate( aTime ); (aTime||Time.now).gmtime.strftime( "%a, %d %b %Y %H:%M:%S GMT" ); end
  def mime(string)
	 MIME[string.split(/\./).last] || "application/octet-stream"
  end
  LICON="&#9728;&#9731;&#9742;&#9745;&#9745;&#9760;&#9763;&#9774;&#9786;&#9730;".split(/;/).map {|c| c+";"}
  MIME={"png" => "image/png", "gif" => "image/gif", "html" => "text/html","htm" => "text/html",
	"js" => "text/javascript" ,"css" => "text/css","jpeg" => "image/jpeg" ,"jpg" => "image/jpeg",
	".json" => "applicatipon/json",
	"pdf"=> "application/pdf"   , "svg" => "image/svg+xml","svgz" => "image/svg+xml",
	"xml" => "text/xml"   ,"xsl" => "text/xml"   ,"bmp" => "image/bmp"  ,"txt" => "text/plain" ,
	"rb"  => "text/plain" ,"pas" => "text/plain" ,"tcl" => "text/plain" ,"java" => "text/plain" ,
	"c" => "text/plain" ,"h" => "text/plain" ,"cpp" => "text/plain", "xul" => "application/vnd.mozilla.xul+xml",
	"doc" => "application/msword", "docx" => "application/msword","dot"=> "application/msword",
	"xls" => "application/vnd.ms-excel","xla" => "application/vnd.ms-excel","xlt" => "application/vnd.ms-excel","xlsx" => "application/vnd.ms-excel",
	"ppt" => "application/vnd.ms-powerpoint",	"pptx" => "application/vnd.ms-powerpoint"
  } 
end # 220 loc webserver :)

class Webserver < WebserverAbstract
  def initialize(port=7080,cadence=10,timeout=120)
    super(port,Dir.getwd(),"",cadence,timeout)
  end
end 
class WebserverRoot < WebserverAbstract
  def initialize(port=7080,root=".",name="wwww",cadence=10,timeout=120,options={})
    super(port,root,name,cadence,timeout,options)
  end
end 
def cliweb()
	Thread.abort_on_exception = false
	BasicSocket.do_not_reverse_lookup = true
	port=59999
	$ws=WebserverRoot.new(port,'.','femto ws',10,300, {});
	puts "Serve path #{Dir.getwd} with port #{port}"
	sleep
end
