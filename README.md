The tinyest web server ...

```ruby
# server all file in current dir and .info request

$ws=WebserverRoot.new(ARGV[0].to_i,".","femto ws",10,300, {})

$ws.serve("/info")    {|p|  
 [200,".html", "Femto demo<hr><a href='/'>site</a><hr>#{$ws.to_table(p)}" ] 
}
```