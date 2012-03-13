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

 - all http header, with key upercase
 - http parameters (?a=b&...)


## License

LGPL
