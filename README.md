[![Gem Version](https://badge.fury.io/rb/raygun-gl.png)](http://badge.fury.io/rb/raygun-gl)
<img src="https://raw.github.com/lastobelus/raygun-gl/master/marvin.jpg" align="right"/>

# Raygun GL

Rails application generator that builds a new project skeleton from prototype app repos which can live either on github or a private gitlab instance.

`raygun-gl` generates Rails 4 projects by copying a sample app and massaging it gently into shape. It is a fork of https://github.com/carbonfive/raygun but does not supply an app prototype. Instead it allows you to use (your own) app prototype repos that are hosted either on **github** or a private **gitlab** instance. If you want to use Carbon Five's app prototype, `raygun-gl` does not provide any extra functionality over Carbon Five's original version (except for the `--embed_as` option)

Major tools/libraries:

* Rails
* PostgreSQL
* Slim
* Sass
* Bootstrap
* RSpec
* Factory Girl
* Jasmine
* SimpleCov
* Guard (rspec, jasmine, livereload)
* And many tweaks, patterns and common recipes (see [raygun-rails](https://github.com/carbonfive/raygun-rails) for all the details).

Raygun includes generator templates for controllers, views, and specs so that generated code follows best
practices. For example, view generation produces bootstrap compatible markup and rspec specs use factory
girl when appropriate.

Inspired by Xavier Shay work at Square and ThoughtBot's Suspenders. Thanks!

## Projects Goals

`raygun-gl`...

* Generates a new rails application that's ready for immediate feature development.
* Generates an application that has best practices that apply to most projects baked in.
* Generates an application that includes specs for all built in functionality.
* Is a forum for discussing what should or should not be included as part of a standard stack.

## Installation

    $ gem install raygun-gl

## Prerequisites

To generate an application, you only need the raygun-gl gem and network connectivity.

The generated app will be configured to use the ruby version that was used to invoke raygun. If you're using
another ruby, just change the ```Gemfile``` and ```.ruby-version``` as necessary.

## Usage

    $ raygun-gl your-project

## Using  Project Template
Once your project is baked out, you can easily kick the wheels. Be sure that you have the prerequities
covered (see above).

    $ cd your-project
    $ ./bin/setup

    # Run the specs, they should all pass
    $ rake

    # Fire up the app and open it in a browser
    $ foreman start
    $ open http://localhost:3000

## Using a Custom Project Template

The default is to use the project at [carbonfive/raygun-rails](https://github.com/carbonfive/raygun-rails) as a
starting point. You can use another repo as the project template with the ```-p```  and/or ```-g``` command line options.

If you invoke raygun-gl with the ```-p``` option, you can specify your own github repository.

    $ raygun -p githubid/repo your-project

The repository must:

* Not have any binary files. Raygun runs a 'sed' command on all files, which will fail on binaries, such as jar files.

For github repos, the repository must have been tagged. Raygun chooses the "greatest" tag and downloads the repository as of that tag -- this is the original way the Carbon Five version. For gitlab repos you can (must) supply a ref (branch or tag) with `-r`

If your project template requires a minimum version of raygun, include the version in a file called
```.raygun-version``` at the root. Raygun will make sure it's new enough for your repo.

If you want to use a project template that lives on a gitlab instance, invoke raygun-gl with the ```-g``` option or set the `GITLAB_API_ENDPOINT` environment variable to your gitlab instance url. Currently, you must also use the `-r` option to specify a ref (branch or tag). You must either set your private token in env `GITLAB_API_PRIVATE_TOKEN`,  or, if using OS X you can store it in your keychain in a generic password named `[gitlab endpoint host]-private-token`

    $ raygun -g https://gitlab.mydomain.com -p gitlabid/repo -r v1.0.0 your-project

## Embed As

If the rails app you are generating is a part of another project (example: the backend in an Ember app), you can use the `--embed_as` option to specify what its directory should be called:

    $ raygun -g https://gitlab.mydomain.com -p gitlabid/repo -r v1.0.0 -e rails /path/to/ember-project

This example will generate a rails app in `/path/to/ember-project/rails`, creating `/path/to/ember-project` if it doesn't exist, and doing `git init` in `/path/to/ember-project` **IF** `/path/to/ember-projec/.git` doesn't already exist before committing the generated app.

## Internal Mechanics

Raygun fetches the greatest tag from the [carbonfive/raygun-rails](https://github.com/carbonfive/raygun-rails)
repo, or the specified branch/tag from the specified repo, unless it already has it cached in ~/.raygun, extracts the contents of the tarball, and runs a series of search-and-replaces on the code to customize it accordingly.

This approach is fast, simple, and makes raygun development very easy. Make changes to the application
prototype (which is a valid rails app) and tag them when they should be used for new applications.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

### Development

Generate an example app using your local development version of raygun-gl:

    $ ./bin/raygun-gl tmp/example_app

## Changes

[View the Change Log](https://github.com/lastobelus/raygun-gl/tree/master/CHANGES.md)
