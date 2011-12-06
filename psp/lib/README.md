This folder currently contains two subprojects:

- Tactic Solver
- Routing Info

# Tactic solver

At present, what the tactic solver tries to achieve, is resolving names into
IP-addresses. It does so using a set of tactics. The tactics can be found in
the tactics subfolder.

To test the tactic solver use the runner_tactic_solver.rb file:

  ruby runner_tactic_solver.rb

## More

For more information on how the tactic solver works, and how to write tactics
for it, please see: [how the tactic solver works](https://github.com/avsm/signpost/blob/master/psp/lib/docs/tactic_solver.md) and
[how to write tactics](https://github.com/avsm/signpost/blob/master/psp/lib/docs/writing_tactics.md).


# Routing info

The routing info component is a component that ensures signposts within
a signpost domain see an eventually consistent view of the world.

In its current form it does not take the new tactic solver into account.

The current version can be tested using the runner_routing_info.rb

  ruby runner_routing_info.rb


# Dependencies

Dependencies are specified in the Gemfile format in the parent directory of the
lib folder. Do get up and running quickly, please use:

  gem install bundler
  bundle install

