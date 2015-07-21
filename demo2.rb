require_relative "lib/femtows.rb"

class App < Fem
  def get_app_html(p)
      "<html><body><h2><center>Hello</center></h2><hr><p>#{content}</p><hr><center>[femtows]</center></body>"
  end
  def content
    to_tableb(Dir.glob("*.rb")) {|f| [f,File.size(f),File.mtime(f)]}
  end
end

App.new(ARGV[0].to_i)
sleep
