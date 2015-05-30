require "./lib/rack_codebreaker"

use Rack::Static, :urls => ["/stylesheets"], :root => "public"
run RackCodebreaker::WebCodebreaker