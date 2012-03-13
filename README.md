# Femtows : femto sized web server
## Presentation 

The tiny web server ...
230 Lines of code.

Build to be embedded in any ruby application, test/debug/admin-debug-access/...

## Install

```bash
gem install femtows
```

## Usage

```ruby
> ruby -rfemtows -e "cliweb()"
> ruby -rfemtows -e "cliweb(8080,'/tmp')"
> femtows.bat
> femtows.sh
```

Embedded:

```ruby
# server all file in current dir and .info request :

$ws=WebserverRoot.new(8080,"/tmp","femto ws",10,300, {})

$ws.serve("/info")    {|p|  
 [200,".html", "Femto demo<hr><a href='/'>site</a><hr>#{$ws.to_table(p)}" ] 
}
```

Servelt receive params hash which content :

 - all http header, with key upercase, prefixed with HEAD
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
