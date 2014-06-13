require 'gitlab'

module Raygun
  class GitlabClient

    attr_accessor :uri
    def initialize(endpoint)
      @uri = URI.parse(endpoint)
      token = ENV['GITLAB_API_PRIVATE_TOKEN']
      unless `which security`.empty?
        cmd = "security 2>&1 >/dev/null find-generic-password -g -l#{@uri.host}-private-token"
        puts "cmd: #{cmd.inspect}"
        token ||= `#{cmd}`.gsub(/password: *"([^"]+)"\n/, '\1')
      end
      puts "token: #{token.inspect}"
      Gitlab.configure do |config|
        config.endpoint       = endpoint
        config.private_token  = token
      end
    end
  end
end