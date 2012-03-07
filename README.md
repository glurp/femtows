# Femtows : femto sized web server
## Presentation 

The tiny web server ...

Made to be embedded in any ruby application, test/debug/adminview/...

## Install

```bash
gem install femtows
```

## Usage

```ruby
# Cli
ruby -rfemtows -e "cliweb()"
or
femtows.bat
ou
femtows.sh
```

Embedded:

```ruby
# server all file in current dir and .info request :

$ws=WebserverRoot.new(ARGV[0].to_i,".","femto ws",10,300, {})

$ws.serve("/info")    {|p|  
 [200,".html", "Femto demo<hr><a href='/'>site</a><hr>#{$ws.to_table(p)}" ] 
}
```

Servelt receive params hash which content :

 - all http header, with key upercase
 - http parameters (?a=b&...)


## License

LGPL
