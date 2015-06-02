require "bundler/setup"
require "erb"
require "codebreaker"
require "yaml"
require "securerandom"

module RackCodebreaker
  class WebCodebreaker
    def self.call(env)
      new(env).response.finish
    end

    def initialize(env)
      @game = Codebreaker::Game.new
      @scores = Array.new
      @request = Rack::Request.new(env)
      @gameplay = Array.new
      @game_uuid = nil
    end

    def response
      @game_uuid = @request.cookies["uuid"] || @game_uuid
      @game = YAML.load(File.open("./data/#{@game_uuid}")) unless Exception
      @gameplay = YAML.load(@request.cookies["gameplay"]) if @request.cookies["gameplay"]
      @scores = YAML.load(File.open("./data/scores.txt"))

      case @request.path

      when "/" then Rack::Response.new(render("index.html.erb"))
      
      when "/start"
        status = @game.start(@request.params["name"], @request.params["attempt_count"].to_i)
        if status == false
          @game_uuid = generate_uuid
          File.open("./data/#{@game_uuid}", 'w') { |file| file.write(YAML.dump(@game)) } 
          @gameplay.clear
          Rack::Response.new do |response|
            del_cookies(response)
            @gameplay.push("____")
            response.set_cookie("gameplay", YAML.dump(@gameplay))
            response.set_cookie("uuid", @game_uuid)
            response.redirect("/game")
          end
        else
          Rack::Response.new do |response|
            response.set_cookie("status", status)
            response.redirect("/")
          end
        end
      
      when "/game"
        Rack::Response.new(render("game.html.erb"))
      
      when "/guess"
        Rack::Response.new do |response|
          @gameplay.push(@request.params["guess"])
          answer = @game.submit_guess(@request.params["guess"])
          File.open("./data/#{@request.cookies["uuid"]}", 'w') { |file| file.write(YAML.dump(@game)) } 
          @gameplay.push(answer)
          response.set_cookie("gameplay", YAML.dump(@gameplay))
          response.set_cookie("guess", @request.params["guess"])
          response.set_cookie("answer", answer)
          response.set_cookie("uuid", @game_uuid)
          if @game.won == true
            @scores = YAML.load(File.open("./data/scores.txt"))
            @scores.push({:name => @game.name, :score => @game.score})
            File.open("./data/scores.txt", 'w') { |file| file.write(YAML.dump(@scores)) } 
            response.set_cookie("score", answer)
            response.redirect("/won")  
          elsif @game.lost == true
            response.set_cookie("lost", answer)
            response.redirect("/lost")    
          else
            response.redirect("/game")
          end
        end

      when "/hint"
        h = @game.use_hint
        File.open("./data/#{@request.cookies["uuid"]}", 'w') { |file| file.write(YAML.dump(@game)) } 
        @gameplay.push(h)
        Rack::Response.new do |response|
          response.set_cookie("uuid", @game_uuid)
          response.set_cookie("gameplay", YAML.dump(@gameplay))
          response.set_cookie("hint", h)
          response.redirect("/game")
        end
      
      when "/won"
        Rack::Response.new(render("won.html.erb"))
      
      when "/lost"
        Rack::Response.new(render("lost.html.erb"))
      
      when "/play_again"
        @game.play_again
        File.open("./data/#{@request.cookies["uuid"]}", 'w') { |file| file.write(YAML.dump(@game)) } 
        Rack::Response.new do |response|
          del_cookies(response)
          @gameplay.clear.push("____")
          response.set_cookie("gameplay", YAML.dump(@gameplay))
          response.set_cookie("uuid", @game_uuid)
          response.redirect("/game")
        end

      else Rack::Response.new("Not Found", 404)
      end
    end

    def render(template)
      path = File.expand_path("../views/#{template}", __FILE__)
      ERB.new(File.read(path)).result(binding)
    end

    def get_cookies
      @request.cookies || nil
    end

    def get_cookie(key)
      @request.cookies[key] || nil
    end

    def get_scores
      @scores
    end

    def get_gameplay
      YAML.load(@request.cookies["gameplay"]) || nil
    end

    def attempt_remains
      @game = YAML.load(File.open("./data/#{@request.cookies["uuid"]}"))
      (@game.attempt_count - @game.guess_count)
    end

    def del_cookies(resp)
      resp.delete_cookie("guess")
      resp.delete_cookie("answer")
      resp.delete_cookie("hint")
      resp.delete_cookie("score")
      resp.delete_cookie("lost")
      resp.delete_cookie("gameplay")
      resp.delete_cookie("uuid")
    end

    def generate_uuid
      SecureRandom.uuid
    end
  end
end
