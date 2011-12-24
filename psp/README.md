# Personal signpost

## Ruby Install

Ruby 1.8.x is required.  Suggestion is to install [RVM](http://beginrescueend.com/)
and use that to manage Rubies and Gems.  For example,

    $ bash < <(curl -s https://raw.github.com/wayneeseguin/rvm/master/binscripts/rvm-installer)
    $ aenv PATH ~/.rvm/bin
    $ rvm install 1.8.7
    $ rvm --default 1.8.7
    $ gem update --system

Also append the following to you `~/.bashrc`:

    [ -s "$HOME/.rvm/scripts/rvm" ] && source "$HOME/.rvm/scripts/rvm" # Load RVM function

## Dependencies

Install [ZeroMQ](http://zeromq.org) first.  [Homebrew](http://mxcl.github.com/homebrew/) on
the Mac lets you do this by:

    brew install zeromq

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
