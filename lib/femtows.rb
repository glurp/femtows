# encoding: utf-8
# FemtoWebServer : 232 LOC web server
#
#   $ws=WebserverRoot.new(port,"/home/www","femto ws",10,300)
#   ws.serve "/FOO" do |params|
#      data=params["HEAD-DATA"]|| ""
#      puts "Recu data len=#{data.length} : <#{data[0..1000]}>" if data
#      [200,".json",""]
# end
  
require 'tmpdir'  
require 'thread'
require 'socket'
require 'timeout'
require 'net/http'

#################### monkey-patching BufferedIO:  timeout read and read/chomp
module Net
  class BufferedIO
	def read_until_chomp(sep)
		s=readuntil(sep)
		s ? s.chomp(sep) : nil
	end
	def read_until_maxsize(terminator,maxsize)
      begin
        while (! idx=@rbuf.index(terminator)) && @rbuf.size < maxsize
          rbuf_fill
        end
        if idx && idx.kind_of?(Numeric) 
		  return rbuf_consume( idx + terminator.size)
		else
		  return rbuf_consume(@rbuf.size)
		end
      rescue EOFError
	    return  (@rbuf.size>0) ? rbuf_consume(@rbuf.size) : nil
      end
    end
  end
end

#################### Tiny embeded webserver


class WebserverAbstract
  def logg(*args) 
	if @cb_log then @cb_log.call(@name,*args) else puts(args.join(" ")) end
  rescue
   puts(args.join(" "))
  end
  def info(txt) ; logg("nw>i>",txt) ;  end
  def error(txt) ; logg("nw>e>",txt) ; end
  def unescape(string) ; string.tr('+', ' ').gsub(/((?:%[0-9a-fA-F]{2}))/n) { [$1.delete('%')].pack('H*') }   end
  def escape(string) ; string.gsub(/([^ \/a-zA-Z0-9_.\-]+)/) { '%' + $1.unpack('H2' * $1.size).join('%').upcase }.tr(' ', '+')  end
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
    raise("tcp port illegal #{port}") unless port.to_i>=80
    raise("root not exist #{root}") unless File.exists?(root)
    @cb_log= options["logg"] 
    @last_mtime=File.mtime(__FILE__)
    @port=port.to_i
    @root=root
    @name=name
    @rootd=root[-1,1]=="/" ? root : root+"/" 
    @timeout=timeout
    @th={}
    @cb={}
    @redirect={}
    info(" serveur http #{port} on #{@rootd} ready!")
    observe(cadence,timeout*2)
    pool_create
    @thm=Thread.new { sleep(0.1); loop { 
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
			sleep(3); info("restart accept")
		}	}
  end
  def pool_create
    @queue=Queue.new
    ici=self
    100.times {  Thread.new { loop { 
      param,bloc=@queue.pop
      bloc.call(param)  rescue p $!
    } } }
  end
  def pool_get(param,&block)
     @queue.push([param,block])
  end
  def touch_session(sess)
	@th[Thread.current]=[Time.now,sess]
  end
  def run(session)
		pool_get(session) do |sess|
		   @th[Thread.current]=[Time.now,sess]
		   request(sess) 
		   @th.delete(Thread.current) 
		end
  end
  def serve(uri,&blk)
    @cb[uri] = blk
    puts(" registered #{uri}")
  end  
  def request(session)
	  request = session.gets
    return unless request
	  uri = (request.split(/\s+/)+['','',''])[1] 
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
  rescue Exception => e
	error("Error Web get on #{request}: \n #{$!.to_s} \n #{$!.backtrace.join("\n     ")}" ) rescue nil
	session.write "HTTP/1.0 501 NOK\r\nContent-type: text/html\r\n\r\n<html><head><title>WS</title></head><body>Error : #{$!}" rescue nil
  ensure
	session.close rescue nil
  end  
  def read_header(session,params)
	   head=session.gets("\r\n\r\n")
	   params=parse_header(head,"HEAD-")
	   if params["HEAD-CONTENT-LENGTH"] &&  params["HEAD-CONTENT-TYPE"] !~ /multipart/
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
		elsif params["HEAD-CONTENT-TYPE"] && params["HEAD-CONTENT-TYPE"]=~ /^multipart\/form-data;\s*boundary=(.*)$/
		  params["HEAD-BOUNDARY"]=$1
		  params["HEAD-INPUT-STREAM"]="multipart" 
		  Thread.current[:socket]=session
		  Thread.current[:head]=params
	   end
  end
  def parse_header(head,prefixe)
	head.split("\r\n").each_with_object({}) { |line,h| 
		name,data=line.split(": ",2)
		h[prefixe+name.upcase]=data 
	}
  end
  def stream_input(&b) # to be call in the get: get("..") { stream_input {|type,name,value,header| } ; [...]}
	socket=Thread.current[:socket]
	params=Thread.current[:head]
	if params["HEAD-INPUT-STREAM"]=="multipart"
		receive_multipart(socket,params["HEAD-BOUNDARY"],params,&b)
	else
	  logg "stream_input() on  unknown type"
	end
  end  

	# Exemple get / multipart :
	# -----------------------------203361401820634              # first boundary, ignored
	# Content-Disposition: form-data; name="text"
    #
	# fqdsfdfqsdfqdfqsdqsdfsdff text input...
	# -----------------------------203361401820634              # normal boundaru : ended by \r\n
	# Content-Disposition: form-data; name="file1"; filename="notes.txt"
	# Content-Type: text/plain
    #
	# FILECONTNE
	# FILECONTNE
	# FILECONTNE
	# FILECONTNE
	# -----------------------------203361401820634
	# Content-Disposition: form-data; name="file2"; filename=""
	# Content-Type: application/octet-stream
    #
	# FILECONTNE
	# FILECONTNE
	# -----------------------------203361401820634--            # last boundary, end with '--'

  
  def receive_multipart(sess,boundary,params,&b)
	bound= "\r\n--#{boundary}"
	
	socket=::Net::BufferedIO.new(sess)
	socket.read_timeout= 120
	socket.continue_timeout= 60
	
	str=socket.read_until_chomp("\r\n") # pass first boundary
	while str!=nil
		touch_session(sess)
		head=socket.read_until_maxsize("\r\n\r\n",2**14)
		break unless head 
	    mparams=parse_header(head,"MHEAD-")
		next if mparams.size==0
		name_field=unescape(mparams["MHEAD-CONTENT-DISPOSITION"][/name="(.*?)"/,1])
		filename=mparams["MHEAD-CONTENT-DISPOSITION"][/filename="(.*?)"/,1]
		if filename
			tmpfile,ended=read_part_file(socket,filename,bound)
			b.call(name_field,:file,tmpfile,mparams)
			break if ended
		else
			data=socket.read_until_chomp(bound)
			b.call(name_field,:text,data,mparams)
			str=socket.read(2)
			break if (str && str=="--" )
		end
	end
	logg "end all part readed"
  end
  def read_part_file(socket,filename,bound)
    filename="unknown" if filename.size==0
	tmpfile="#{Dir.tmpdir()}/femtows_#{filename}_#{(Time.now.to_f*1000).round}"
	File.remove(tmpfile) if File.exists?(tmpfile)  
	open(tmpfile,"wb:ASCII-8BIT") do |f|
		while  str=socket.read_until_maxsize(bound,2**20)
			if str.end_with?(bound)
			  f.print(str[0,str.size-bound.size])
			  break
			else
			  f.print(str)
			end
		end
	end
	str=socket.read(2)
	ended=(str && str=="--" ) ? true : false
	#logg " end geting part type=file, tmp=",tmpfile,"size=",File.size(tmpfile)
	return [tmpfile,ended]
  end
  def redirect(o,d)
   @redirect[o]=d
  end  
  def do_service(session,request,service,user_passwd,params)
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
       logg session.peeraddr.last,"Error in get /#{service} : #{$!} \n   #{$!.backtrace.join("\n   ")}"
       sendError(session,501,"#{$!} : at #{$!.backtrace.first}")
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
	[@tho,@thm].each { |th| th.kill }
	@server.close rescue nil
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
	Timeout.timeout([s/(512*1024),30.0].max.to_i) {
		sock.write "HTTP/1.0 200 OK\r\nContent-Type: #{mime(filename)}\r\nContent-Length: #{File.size(filename)}\r\nLast-Modified: #{httpdate(File.mtime(filename))}\r\nDate: #{httpdate(Time.now)}\r\n\r\n"
		File.open(filename,"rb") do |f| 
		  f.binmode; sock.binmode; 
		  ( sock.write(f.read(32*1024)) while (! f.eof? && ! sock.closed?) ) rescue nil
		end
	} 
  end
  def httpdate( aTime=nil ); (aTime||Time.now).gmtime.strftime( "%a, %d %b %Y %H:%M:%S GMT" ); end
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
def cliweb(root=Dir.getwd,port=59999)
	Thread.abort_on_exception = false
	BasicSocket.do_not_reverse_lookup = true
	$ws=WebserverRoot.new(port,root,'femto ws',10,300, {});
	puts "Server root path #{root} with port #{port}"
	sleep
end
###################### another api
class Fem < WebserverAbstract
  def initialize(port=7080,root=".",name="wwww",cadence=10,timeout=120)
    super(port,root,name,cadence,timeout,{})
    introspect
  end
  def introspect()
    exp=/^(get|post)_(\w[\w\d]*)_(\w+)$/
    methods.grep(exp).each { |name| 
      all,method,key,mime= exp.match(name).to_a
      serve("/#{key}") { |par| [200,".#{mime}",self.send(all,par)] }
    }
  end
end