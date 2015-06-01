require "./lib/rack_codebreaker"

use Rack::Static, :urls => ["/stylesheets"], :root => "public"
use Rack::Reloader
run RackCodebreaker::WebCodebreaker