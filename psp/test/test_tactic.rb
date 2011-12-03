require 'test_common'

class TestSolver
  include Bud
  include TacticProtocol

  def initialize
    options = {}
    super options
    self.run_bg
  end

  state do
    table :data
    table :truths
  end

  bloom :receive_need do
    need_truth_scratch <= need_truth.payloads
    data <= need_truth_scratch

    provide_truth_scratch <= provide_truth.payloads
    truths <= provide_truth_scratch
  end
end

class TestTactic < MiniTest::Unit::TestCase
  def setup
    @solver = TestSolver.new
    @tactic = TacticSolver::Tactic.new "unit_test", @solver.ip_port
  end

  def teardown
    @tactic.shut_down
    @solver.stop
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

  def test_pass_on_truth
    # This is a very roundabout kind of test
    # The unit_test tactic passes all truths it receives back
    # as a new truth.
    # In order to test it, we therefore pass some truths on to the tactic,
    # and verify that they appear in the solver as truths

    truth_source = "unit_testing_truth"

    truth = "a_truth"
    value = "truth_value"
    @tactic.send(:pass_on_truth, truth, truth_source, value)

    other_truth = "other_truth"
    other_value = "other_truth_value"
    @tactic.send(:pass_on_truth, other_truth, truth_source, other_value)

    @tactic.tick

    sleep(0.3)

    # The test_unit tactic should have changed the source of the truth
    # to be itself. We therefore have to make sure the original truth source
    # is not the same as the tactic name
    name = @tactic.instance_variable_get("@name")
    assert truth_source != name, "Tactic name should not be the same as original truth source"

    # The test unit will have passed the truth back into the solver
    truths = @solver.truths.to_a

    t = truths[0]
    assert_equal truth, t[0]
    assert_equal name, t[1]
    assert_equal [value], t[2]
    t = truths[1]
    assert_equal other_truth, t[0]
    assert_equal name, t[1]
    assert_equal [other_value], t[2]
  end

  # The tactics should be able to contribute truths back to the solver
  def test_add_truth
    truth = "a_truth"
    value = "truth_value"
    @tactic.send(:add_truth, truth, value)
    other_truth = "other_truth"
    other_value = "other_truth_value"
    @tactic.send(:add_truth, other_truth, other_value)
    @tactic.tick
    sleep(0.1)
    truths = @solver.truths.to_a
    name = @tactic.instance_variable_get("@name")
    t = truths[0]
    assert_equal truth, t[0]
    assert_equal name, t[1]
    assert_equal [value], t[2]
    t = truths[1]
    assert_equal other_truth, t[0]
    assert_equal name, t[1]
    assert_equal [other_value], t[2]
  end

  # The requirement should be added to the main solver
  def test_add_requirement
    truth = "truth_type"
    other_truth = "other_truth_type_needed"
    @tactic.send(:add_requirement, truth)
    @tactic.send(:add_requirement, other_truth)
    sleep(0.1) # UGLY! We need to wait so that the data can propagate through bud
    data = @solver.data
    assert_needs data, truth
    assert_needs data, other_truth
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

    # The unit_test tactic passes all its truths back to
    # the main repo.
    # Check that we got it back.
    # np = @tactic.needed_parameters
    # assert_needs np, "test_local:8080@local:8080"
    # assert_needs np, "test_8080@local"
    # assert_needs np, "test_local@local:8080"
    # assert_needs np, "test_unit_testing@local:8080"
  end

private
  def assert_needs p, what
    assert (p.to_a.select {|t| t[0] == what}).size == 1, "Should have #{what} added as a need"
  end
end
