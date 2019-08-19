# Femtows : femto sized web server
## Presentation 

The tiny web server ...
400 Lines of code.

Build to be embedded in any ruby application, test/debug/admin access...

Features :

* methods GET POST (PUT, REMOVE, HEAD... are missing!)
* index generate as simple explorer (if path correspond to existant directory or file)
* multipart/data supported
* upload file via multipart
* multipart dynamic (can be active continiously, a timeout inter-part is setted to 10 minutes)
* http redirection

Performences are not to bad : better then default Rack server, best than  Sinatra/Thin)

## Install

```bash
gem install femtows
```

## Usage

As file http server :
```ruby
> ruby -rfemtows -e "cliweb()"
> ruby -rfemtows -e "cliweb('/tmp',8080)"
or
> femtows.bat
# femtows.sh
```

### Embedded V1:

```ruby
# server all file in current dir and .info request :

$ws=WebserverRoot.new(8080,"/tmp","femto ws",10,300, {})

$ws.serve("/info")    {|p|  
 [200,".html", "Femto demo<hr><a href='/'>site</a><hr>#{$ws.to_table(p)}" ] 
}
```

### Embedded V2:
```ruby
class App < Fem
  def get_app_html(p)
    "<html><body><h2><center>Hello</center></h2><hr>
      <p>#{content}</p><hr><center>[femtows]</center>
    </body></html>"
  end
  def content
    to_tableb(Dir.glob("*.rb")) {|f| [f,File.size(f),File.mtime(f)]}
  end
end
App.new(ARGV[0].to_i)
```

#### Upload file 

```ruby
class App < Fem
  def get_app_html(p)
	  form=<<EEND
<form action="mp" method="post" enctype="multipart/form-data">
  <p><input type="text" name="text" value="dddddddddddddddd">
  <p><input type="file" name="file1">
  <p><input type="file" name="file2">
  <p><button type="submit">Submit</button>
</form>
EEND
      "<html><body><h2><center>Hello</center></h2><hr><p>#{form}</p><hr><center>[femtows]</center></body>"
  end
  def get_mp_html(p)
	bilan={}
	stream_input { |name,type,value,headers|
		puts ["!!!!!!!!!! stream_input reactor ==> ",name,type,value,headers].join(" ")
		puts("           File size of %s  => %d" % [value,File.size(value)]) if type==:file
		size= (type==:file) ? File.size(value) : -1
		bilan[name]=[type,value,size]
	}
    "<html><body><h2><center>Stream input (multipart)</center></h2><hr><p>#{bilan.inspect.split(",").join("<br>")}</p><hr><center>[femtows]</center></body>"
  end
end
```

With v2 API, all methods which name match get_(*)_(*) will be associate with url $1
and his output will be sending with MIME code corresponding to file extension $2.

So ```def get_login_html()``` while match for path /login,method GET or POST, end returned value is sended as Content-type: ```text/html```



## API

```ruby
WebserverRoot.new(
	port_http,  # server http  port (>1024 on posix, if not root)
	root-dir,	# only one file root. indexed by defalut
	ws_name,	# name in trace & index title 
	10,300, 	# watch too long connection: every  10 secondes, 
				    # kill session which have started from more than 300 seconds
	{}			  # options. only one, for logg events , see demo.rb
)
```

Servlet receive params hash which content :

 - all http header, with key upercase, prefixed with 'HEAD-'
 - http parameters (?a=b&...)

Exemple : http://localhost:9980/info?aa=bb&cc=dd, give with p.to_a.inspect:

```
["aa", "bb"]
["cc", "dd"]
["HEAD-HOST", "localhost:9980"]
["HEAD-USER-AGENT", "Mozilla/5.0 (Windows NT 6.1; WOW64; rv:10.0.2) Gecko/20100101 Firefox/10.0.2"]
["HEAD-ACCEPT", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"]
["HEAD-ACCEPT-LANGUAGE", "fr,fr-fr;q=0.8,en-us;q=0.5,en;q=0.3"]
["HEAD-ACCEPT-ENCODING", "gzip, deflate"]
["HEAD-CONNECTION", "keep-alive"]
```
## License

LGPL
