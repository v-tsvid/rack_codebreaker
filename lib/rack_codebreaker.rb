require "erb"

module RackCodebreaker
  class WebCodebreaker
    def self.call(env)
      new(env).response.finish
    end

    def initialize(env)
      @request = Rack::Request.new(env)
    end

    def response
      Rack::Response.new(render("index.html.erb"))
      # case @request.path
      # when true then true
      # else false
      # end
    end

    def render(template)
      path = File.expand_path("../views/#{template}", __FILE__)
      ERB.new(File.read(path)).result(binding)
    end
  end
end
