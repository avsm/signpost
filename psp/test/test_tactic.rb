require 'test_common'

class TestTactic < MiniTest::Unit::TestCase
  def setup
    @tactic = TacticSolver::Tactic.new "unit_test", "localhost:404040"
  end

  def test_setting_magic_variables
    @tactic.send(:set_the_magic_variables, "service@localhost:80")
    assert_equal "service", @tactic.instance_variable_get("@resource")
    assert_equal 80, @tactic.instance_variable_get("@port")
    assert_equal "localhost:80", @tactic.instance_variable_get("@destination")
    assert_equal "localhost", @tactic.instance_variable_get("@domain")

    @tactic.send(:set_the_magic_variables, "service@localhost")
    assert_equal "service", @tactic.instance_variable_get("@resource")
    assert_equal nil, @tactic.instance_variable_get("@port")
    assert_equal "localhost", @tactic.instance_variable_get("@destination")
    assert_equal "localhost", @tactic.instance_variable_get("@domain")
  end

  def test_requirements
    # Setup magic variables
    @tactic.send(:set_the_magic_variables, "service@domain:8080")
    # Resource = service
    # Domain = domain
    # Destination = domain:8080
    # Port = 8080

    res = @tactic.send(:requirements, ["tcp_out@Destination"]).first
    assert_equal "tcp_out@domain:8080", res

    res = @tactic.send(:requirements, ["Resource@Domain"]).first
    assert_equal "service@domain", res

    res = @tactic.send(:requirements, ["ssh_Domain@Port"]).first
    assert_equal "ssh_domain@8080", res

    res = @tactic.send(:requirements, ["ssh_Destination@Destination"]).first
    assert_equal "ssh_domain:8080@domain:8080", res

    res = @tactic.send(:requirements, ["ssh_Destination_Port_Port@Destination"]).first
    assert_equal "ssh_domain:8080_8080_8080@domain:8080", res
  end

  def test_add_truth
    truth = "a_truth"
    source = "the_source"
    value = "truth_value"
    @tactic.send(:add_truth, truth, source, value)
    other_truth = "other_truth"
    other_source = "other_source"
    other_value = "other_truth_value"
    @tactic.send(:add_truth, other_truth, other_source, other_value)
    @tactic.tick
    truths = @tactic.parameters
    assert (truths.to_a.select {|t| 
      t[0] == truth and t[1] == source and t[2] == value
    }).size == 1, "Should have the added parameter/truth"
  end

  def test_add_requirement
    truth = "truth_type"
    other_truth = "other_truth_type_needed"
    @tactic.send(:add_requirement, truth)
    @tactic.send(:add_requirement, other_truth)
    @tactic.tick
    needed_parameters = @tactic.needed_parameters
    assert_needs needed_parameters, truth
  end

  def test_execute_unsupported_resource
    # The unit test thing should support
    # - unit_testing@local:8080
    #
    # It requires
    # - test_Destination@Destination 
    # - test_Port@local
    # - test_Domain@local:Port
    # - test_Resource@Destination

    # Should raise an exception for unsupported whats
    assert_raises (TacticSolver::FailedTactic) do
      @tactic.execute "unsupported_unit_testing@local:8080"
    end
  end

  def test_execute_supported_resource
    # The unit test thing should support
    # - unit_testing@local:8080
    #
    # It requires
    # - test_Destination@Destination 
    # - test_Port@local
    # - test_Domain@local:Port
    # - test_Resource@Destination

    @tactic.execute "unit_testing@local:8080"
    @tactic.tick
    np = @tactic.needed_parameters
    assert_needs np, "test_local:8080@local:8080"
    assert_needs np, "test_8080@local"
    assert_needs np, "test_local@local:8080"
    assert_needs np, "test_unit_testing@local:8080"
  end

private
  def assert_needs p, what
    assert (p.to_a.select {|t| 
      t[0] == what and t[1] == true # Should be a requested truth
    }).size == 1, "Should have #{what} added as a needed requirement"
  end
end
