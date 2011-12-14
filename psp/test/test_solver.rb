require 'test_common'

class TestSolver < MiniTest::Unit::TestCase
  def setup
    @node = "test_node"
    @solver = TacticSolver::Solver.new @node
  end

  def teardown
    @solver.stop
  end

  def test_tactics_unsubscribe_when_terminated
    user_info = "user_info_A"
    tactic = TacticSolver::Tactic.new "unit_test", 
        @solver.get_ip_port, @node, user_info
    tactic.execute "unit_testing@local:8080"
    sleep(1)
    subscriptions = @solver.truth_subscribers.to_a
    assert_there_are_subscriptions_for "test_tactic", subscriptions, user_info

    # Now terminate the tactic.
    # This should ensure that there are no subscriptions from that
    # tactic remaining.
    tactic.shut_down 
    sleep(1)
    @solver.tick # Deletions happen at the beginning of the next timestep, so need a tick
    subscriptions_after_shutdown = @solver.truth_subscribers.to_a
    assert (subscriptions != subscriptions_after_shutdown), "Should have removed subscriptions"
    assert_there_are_no_subscriptions_for "test_tactic", subscriptions_after_shutdown, user_info

  end

private
  def assert_there_are_no_subscriptions_for tactic_name, subs, user_info
    subs.each do |sub|
      assert(sub[3] != user_info, "Tactic should not have subs") if sub[2] == tactic_name
    end
  end

  def assert_there_are_subscriptions_for tactic_name, subs, user_info
    that_there_are = false
    subs.each do |sub|
      that_there_are = true if (sub[2] == tactic_name && sub[3] == user_info)
    end
    assert that_there_are, "There should be a subscription for #{tactic_name}"
  end

end
