require 'gitlab'

module Raygun
  class GitlabClient

    attr_accessor :uri, :endpoint, :token
    def initialize(endpoint)
      @endpoint = URI.parse(endpoint)
      @token = ENV['GITLAB_API_PRIVATE_TOKEN']
      unless `which security`.empty?
        cmd = "security 2>&1 >/dev/null find-generic-password -g -l#{@endpoint.host}-private-token"
        @token ||= `#{cmd}`.gsub(/password: *"([^"]+)"\n/, '\1')
      end
      Gitlab.configure do |config|
        config.endpoint       = endpoint
        config.private_token  = @token
      end
    end
    
    def domain
      endpoint.host
    end
  end
end