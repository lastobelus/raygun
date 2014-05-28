module Raygun
  class GitlabClient

    def initialize(endpoint)
      token = ENV['GITLAB_API_PRIVATE_TOKEN']
      token ||= `security 2>&1 >/dev/null find-generic-password -g -l#{@gitlab_endpoint}-private-token`.gsub(/password: *"([^"]+)"\n/, '\1')
      Gitlab.configure do |config|
        config.endpoint       = endpoint
        config.private_token  = token
      end
    end
  end
end