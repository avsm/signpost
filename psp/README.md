# Personal signpost

### Ubuntu Quick Install

On an ubuntu machine, to get from zero to up and running, do the following:

    apt-get install git vim ruby1.8 rubygems

    # Update to latest rubygems
    gem install rubygems-update
    update_rubygems

    # NOTE: In ubuntu 11.04, you might need to add the ruby gem executable
    # directory to your path: /var/lib/gems/1.8/bin (or appropriate version)
    # e.g. 'export PATH=$PATH:/var/lib/gems/1.8/bin'

    gem install bundler

    git clone git://github.com/avsm/signpost.git
    cd signpost/psp
    bundle install

    cp config.yml.sample config.yml
    vim config.yml
    # Edit signpost_client to SOMETHING.kle.io
    
    # Test setup
    ruby runner_tactic_solver.rb

    # See which signposts you are connected to:
    sp

    # Resolve your first truth
    r ip_for_domain@www.kle.io



### Requirements

You'll need to have the following installed and the rest of this Readme will guide you through.

- GCC (via Xcode if you're on a Mac)
- Ruby 1.8.x
- Other dependencies (via bundler)

## GCC

Required for the compilation step during the Ruby install. Xcode is the easiest way to install 
this on a Mac. You can download Xcode 3.2.6 from Apple's dev site.

	http://developer.apple.com/xcode/index.php

## Ruby Install

Ruby 1.8.x is required.  Suggestion is to install [RVM](http://beginrescueend.com/)
and use that to manage Rubies and Gems.  For example,

    $ bash < <(curl -s https://raw.github.com/wayneeseguin/rvm/master/binscripts/rvm-installer)
    $ aenv PATH ~/.rvm/bin
    $ rvm install 1.8.7
    $ rvm --default 1.8.7
    $ gem update --system

If the *aenv* command doesn't work for you, don't worry. Just add `~/.rvm/bin` to your PATH manually 
(see below). Also append the following to your `~/.bashrc` or `~/.bash_profile` (replacing '$HOME' 
with the path to your home directory):

	PATH="${PATH}:~/.rvm/bin"

    [ -s "$HOME/.rvm/scripts/rvm" ] && source "$HOME/.rvm/scripts/rvm" # Load RVM function

## Dependencies

Please use bundler to install the dependencies:

    gem install bundler
    bundle install

Please note that for the tactic solver to work, you currently need
to be running ruby version 1.8.X. This is a requirement for one of
its dependencies.

## Parts

The parts currently being developed are in the lib folder.
For more specifics on the tactic solver, please see the tactic_solver
subfolder in the lib directory.

*This is a work in progress, if you ever saw one, so please don't
build on this, unless you are willing to change things later.*
