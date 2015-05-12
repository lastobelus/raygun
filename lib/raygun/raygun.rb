require 'optparse'
require 'ostruct'
require 'fileutils'
require 'securerandom'
require 'net/http'
require 'json'
require 'colorize'

require_relative 'version'
require_relative 'gitlab_client'

module Raygun
  class Runner
    CARBONFIVE_REPO = 'carbonfive/raygun-rails'

    attr_accessor :target_dir, :app_dir, :app_name, :dash_name, :snake_name, :camel_name, :title_name, :prototype_repo,
                  :gitlab_endpoint, :ref, :embed_as, :current_ruby_version, :current_ruby_patch_level

    def initialize(target_dir, prototype_repo, gitlab_endpoint, ref, embed_as)
      @target_dir     = target_dir
      @app_dir        = File.expand_path(target_dir.strip.to_s)
      @app_name       = File.basename(app_dir).gsub(/\s+/, '-')
      @dash_name      = app_name.gsub('_', '-')
      @snake_name     = app_name.gsub('-', '_')
      @camel_name     = camelize(snake_name)
      @title_name     = titleize(snake_name)
      @prototype_repo = prototype_repo
      @gitlab_endpoint = gitlab_endpoint
      @ref = ref
      @embed_as = embed_as
      if embed_as
        FileUtils.mkdir_p(app_dir) unless File.exist?(app_dir)
        @app_dir = File.join(app_dir, embed_as)
      end
      
      @current_ruby_version     = RUBY_VERSION
      @current_ruby_patch_level = if RUBY_VERSION < '2.1.0' # Ruby adopted semver starting with 2.1.0.
                                   "#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL}"
                                  else
                                    "#{RUBY_VERSION}"
                                  end
    end

    def check_target
      unless Dir["#{@app_dir}/*"].empty?
        puts "Misfire! The target directory isn't empty... aim elsewhere."
        exit 1
      end
    end


    def gitlab?
      !!@gitlab_endpoint
    end
    
    def gitlab_client
      @gitlab_client ||= GitlabClient.new(gitlab_endpoint)
    end
    
    def gitlab_project_id
      @gitlab_project_id ||= parse_gitlab_project_id
    end
    
    def parse_gitlab_project_id
      if prototype_repo.to_i == prototype_repo
        prototype_repo
      else
        
      end
    end
    
    def fetch_prototype
      if gitlab?
        fetch_prototype_from_gitlab
      else
        fetch_prototype_from_github
      end
    end

    def cached_prototypes_dir; File.join(Dir.home, ".raygun"); end
    
    def fetch_prototype_from_gitlab
      print "Checking for the latest application prototype on gitlab...".colorize(:yellow)
      $stdout.flush
      
      latest_tag = ref || fetch_latest_tag_gitlab(prototype_repo)
      
      gitlab_cached_prototypes_dir = File.join(cached_prototypes_dir, gitlab_client.domain)
      @prototype = File.join(gitlab_cached_prototypes_dir, "#{prototype_repo.sub('/', '--')}-#{latest_tag}.tar.gz")
      
      

      if File.exists?(@prototype)
        puts " Using cached version.".colorize(:yellow)
      else
        print " Downloading...".colorize(:yellow)
        $stdout.flush

        # Download the tarball and install in the cache.
        Dir.mkdir(gitlab_cached_prototypes_dir, 0755) unless Dir.exists?(gitlab_cached_prototypes_dir)
        tarball_url = URI([gitlab_endpoint, prototype_repo, "repository", "archive.tar.gz"].join('/'))
        tarball_url.query = URI.encode_www_form(private_token: gitlab_client.token, ref: latest_tag)

        shell "curl -s -L '#{tarball_url.to_s}' -o #{@prototype}"
        puts " done!".colorize(:yellow)
      end
      
      $stdout.flush
    end
    
    
    def fetch_prototype_from_github
      print "Checking for the latest application prototype...".colorize(:yellow)
      $stdout.flush

      # Check if we can connect, or fail gracefully and use the latest cached version.
      latest_tag_obj = fetch_latest_tag(prototype_repo)
      latest_tag     = latest_tag_obj['name']
      tarball_url    = latest_tag_obj['tarball_url']

      print " #{latest_tag}.".colorize(:white)
      $stdout.flush

      @prototype = "#{cached_prototypes_dir}/#{prototype_repo.sub('/', '--')}-#{latest_tag}.tar.gz"

      # Do we already have the tarball cached under ~/.raygun?
      if File.exists?(@prototype)
        puts " Using cached version.".colorize(:yellow)
      else
        print " Downloading...".colorize(:yellow)
        $stdout.flush

        # Download the tarball and install in the cache.
        Dir.mkdir(cached_prototypes_dir, 0755) unless Dir.exists?(cached_prototypes_dir)

        shell "curl -s -L #{tarball_url} -o #{@prototype}"
        puts " done!".colorize(:yellow)
      end
    end

    def check_raygun_version
      required_raygun_version =
        %x{tar xfz #{@prototype} --include "*.raygun-version" -O 2> /dev/null}.chomp ||
          ::Raygun::VERSION

      if Gem::Version.new(required_raygun_version) > Gem::Version.new(::Raygun::VERSION)
        puts  ""
        print "Hold up!".colorize(:red)
        print " This version of the raygun gem (".colorize(:light_red)
        print "#{::Raygun::VERSION})".colorize(:white)
        print " is too old to generate this application (needs ".colorize(:light_red)
        print "#{required_raygun_version}".colorize(:white)
        puts  " or newer).".colorize(:light_red)
        puts  ""
        print "Please update the gem by running ".colorize(:light_red)
        print "gem update raygun".colorize(:white)
        puts  ", and try again. Thanks!".colorize(:light_red)
        puts  ""
        exit 1
      end
    end

    def copy_prototype
      FileUtils.mkdir_p(app_dir)

      shell "tar xfz #{@prototype} -C #{app_dir}"

      # Github includes an extra directory layer in the tag tarball.
      extraneous_dir = Dir.glob("#{app_dir}/*").first
      dirs_to_move   = Dir.glob("#{extraneous_dir}/*", File::FNM_DOTMATCH)
                          .reject { |d| %w{. ..}.include?(File.basename(d)) }

      FileUtils.mv         dirs_to_move, app_dir
      FileUtils.remove_dir extraneous_dir
    end

    def rename_new_app
      Dir.chdir(app_dir) do
        {
          'AppPrototype'  => camel_name,
          'app-prototype' => dash_name,
          'app_prototype' => snake_name,
          'App Prototype' => title_name
        }.each do |proto_name, new_name|
          shell "find . -type f -print | xargs #{sed_i} 's/#{proto_name}/#{new_name}/g'"
        end
      end
    end

    def configure_new_app
      clean_up_unwanted_files

      update_ruby_version

      initialize_git
    end

    def clean_up_unwanted_files
      FileUtils.rm "#{app_dir}/.raygun-version", force: true
    end

    def update_ruby_version
      prototype_ruby_patch_level = File.read(File.expand_path("#{app_dir}/.ruby-version", __FILE__)).strip
      prototype_ruby_version     = prototype_ruby_patch_level.match(/(\d\.\d\.\d).*/)[1]

      Dir.chdir(app_dir) do
        shell "#{sed_i} 's/#{prototype_ruby_patch_level}/#{@current_ruby_patch_level}/g' .ruby-version README.md"
        shell "#{sed_i} 's/#{prototype_ruby_version}/#{@current_ruby_version}/g' Gemfile"
      end
    end

    def initialize_git
      dir = app_dir
      dir = File.join(dir, '..') if embed_as
      Dir.chdir(dir) do
        shell "git init" unless (embed_as && File.exist?('.git'))
        shell "git add -A ."
        shell "git commit -m 'Raygun-zapped skeleton.'"
      end
    end

    def print_plan
      puts '     ____ '.colorize(:light_yellow)
      puts '    / __ \____ ___  ______ ___  ______ '.colorize(:light_yellow)
      puts '   / /_/ / __ `/ / / / __ `/ / / / __ \ '.colorize(:light_yellow)
      puts '  / _, _/ /_/ / /_/ / /_/ / /_/ / / / / '.colorize(:light_yellow)
      puts ' /_/ |_|\__,_/\__, /\__, /\__,_/_/ /_/ '.colorize(:light_yellow)
      puts '             /____//____/ '.colorize(:light_yellow)
      puts
      puts "Raygun will create new app in directory:".colorize(:yellow) + " #{target_dir}".colorize(:yellow) + "...".colorize(:yellow)
      puts
      puts "-".colorize(:blue) +   " Application Name:".colorize(:light_blue) + " #{title_name}".colorize(:light_green)
      if gitlab?
        puts "-".colorize(:blue) + " Gitlab Endpoint: ".colorize(:light_blue) + " #{gitlab_endpoint}".colorize(:light_green)
      end
      puts "-".colorize(:blue) +   " Project Template:".colorize(:light_blue) + " #{prototype_repo}".colorize(:light_green)
      if ref
        puts "-".colorize(:blue) + " Branch/Tag:      ".colorize(:light_blue) + " #{ref}".colorize(:light_green)
      end
      if embed_as
        puts "-".colorize(:blue) + " Embed as:        ".colorize(:light_blue) + " #{embed_as}".colorize(:light_green)
      end
      puts "-".colorize(:blue) +   " Ruby Version:    ".colorize(:light_blue) + " #{@current_ruby_patch_level}".colorize(:light_green)
      puts
    end

    def print_next_steps
      if @prototype_repo == CARBONFIVE_REPO
        print_next_steps_carbon_five
      else
        print_next_steps_for_custom_repo
      end
    end
    
    def print_next_steps_carbon_five
      puts ""
      puts "Zap! Your application is ready. Next steps...".colorize(:yellow)
      puts ""
      puts "# Install updated dependencies and prepare the database".colorize(:light_green)
      puts "$".colorize(:blue) + " cd #{target_dir}".colorize(:light_blue)
      puts "$".colorize(:blue) + " ./bin/setup".colorize(:light_blue)
      puts ""
      puts "# Run the specs (they should all pass)".colorize(:light_green)
      puts "$".colorize(:blue) + " rake".colorize(:light_blue)
      puts ""
      puts "# Run the app and check things out".colorize(:light_green)
      puts "$".colorize(:blue) + " foreman start".colorize(:light_blue)
      puts "$".colorize(:blue) + " open http://localhost:3000".colorize(:light_blue)
      puts ""
      puts "Enjoy your Carbon Five flavored Rails application!".colorize(:yellow)
    end
    
    def print_next_steps_for_custom_repo
      puts ""
      puts "Zap! Your application is ready.".colorize(:yellow)
      puts ""
      puts "Enjoy your raygun generated application!".colorize(:yellow)
    end

    protected

    
    # Fetch the tags for the repo (e.g. 'carbonfive/raygun-rails') and return the latest as JSON.
    def fetch_latest_tag(repo)
      url          = "https://api.github.com/repos/#{repo}/tags"
      uri          = URI.parse(url)
      http         = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request      = Net::HTTP::Get.new(URI.encode(url))

      response     = http.request(request)

      unless response.code == "200" 
        puts  ""
        print "Whoops - need to try again!".colorize(:red)
        puts  ""
        print "We could not find (".colorize(:light_red)
        print "#{repo}".colorize(:white)
        print ") on github.".colorize(:light_red)
        puts  ""
        print "The response from github was a (".colorize(:light_red)
        print "#{response.code}".colorize(:white)
        puts  ") which I'm sure you can fix right up!".colorize(:light_red)
        puts  ""
        exit 1
      end

      result = JSON.parse(response.body).first
      unless result
        puts  ""
        print "Whoops - need to try again!".colorize(:red)
        puts  ""
        print "We could not find any tags in the repo (".colorize(:light_red)
        print "#{repo}".colorize(:white)
        print ") on github.".colorize(:light_red)
        puts  ""
        print "Raygun uses the 'largest' tag in a repository, where tags are sorted alphanumerically.".colorize(:light_red)
        puts  ""
        print "E.g., tag 'v.0.10.0' > 'v.0.9.9' and 'x' > 'a'.".colorize(:light_red)
        print ""
        puts  ""
        exit 1
      end
      
      result
    end

    def fetch_latest_tag_gitlab(repo)
      puts "latest tag not implemented. Please supply a ref with -r".colorize(:red)
      exit 1
    end
    
    def camelize(string)
      result = string.sub(/^[a-z\d]*/) { $&.capitalize }
      result.gsub(/(?:_|(\/))([a-z\d]*)/) { "#{$1}#{$2.capitalize}" }
    end

    def titleize(underscored_string)
      result = underscored_string.gsub(/_/, ' ')
      result.gsub(/\b('?[a-z])/) { $1.capitalize }
    end

    # Distinguish BSD vs GNU sed with the --version flag (only present in GNU sed).
    def sed_i
      @sed_format ||= begin
        %x{sed --version &> /dev/null}
        $?.success? ? "sed -i" : "sed -i ''"
      end
    end

    # Run a shell command and raise an exception if it fails.
    def shell(command)
      %x{#{command}}
      raise "#{command} failed with status #{$?.exitstatus}." unless $?.success?
    end

    def self.parse(args)
      raygun = nil

      options = OpenStruct.new
      options.target_dir     = nil
      options.prototype_repo = CARBONFIVE_REPO
      options.gitlab_endpoint = nil

      parser = OptionParser.new do |opts|
        opts.banner = "Usage: raygun [options] NEW_APP_DIRECTORY"

        opts.on('-h', '--help', "Show raygun usage") do
          usage_and_exit(opts)
        end
        opts.on('-p', '--prototype [github_repo]', "Prototype github repo (e.g. carbonfive/raygun-rails).") do |prototype|
          options.prototype_repo = prototype
        end
        opts.on('-g', '--gitlab [gitlab_endpoint]', "Gitlab instance where the prototype repo can be found.") do |gitlab|
          gitlab ||= ENV['GITLAB_API_ENDPOINT']
          if gitlab.nil? || gitlab.empty?
            raise "--gitlab specified with no endpoint and $GITLAB_API_ENDPOINT was empty"
          end
          options.gitlab_endpoint = gitlab
        end
        opts.on('-r', '--ref [branch-or-tag]', "Git ref on prototype-repo (defaults to 'greatest' tag).") do |ref|
          options.ref = ref
        end
        opts.on('-e', '--embed [sub-dir-name]', "App is sub-dir in existing project.") do |embed_as|
          options.embed_as = embed_as
        end
      end

      begin
        parser.parse!
        options.target_dir = ARGV.first

        raise OptionParser::InvalidOption if options.target_dir.nil?

        raygun = Raygun::Runner.new(options.target_dir, options.prototype_repo, options.gitlab_endpoint, options.ref, options.embed_as)

      rescue OptionParser::InvalidOption
        usage_and_exit(parser)
      end

      raygun
    end

    def self.usage_and_exit(parser)
      puts parser
      exit 1
    end
  end
end
