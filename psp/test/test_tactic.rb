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
    table :needs
    table :truths
  end

  bloom :receive_need do
    need_truth_scratch <= need_truth.payloads
    needs <= need_truth_scratch

    provide_truth_scratch <= provide_truth.payloads
    truths <= provide_truth_scratch
  end
end

class TestTactic < MiniTest::Unit::TestCase
  def setup
    @user_info = "user_info"
    @solver = TestSolver.new
    @tactic = TacticSolver::Tactic.new "unit_test", 
        @solver.ip_port, "node_name", @user_info
  end

  def teardown
    @solver.stop
  end

  def test_setting_magic_variables
    @tactic.send(:set_the_magic_variables, "service@localhost:80")
    assert_equal "service", @tactic.instance_variable_get("@_resource")
    assert_equal 80, @tactic.instance_variable_get("@_port")
    assert_equal "localhost:80", @tactic.instance_variable_get("@_destination")
    assert_equal "localhost", @tactic.instance_variable_get("@_domain")

    @tactic.send(:set_the_magic_variables, "service@localhost")
    assert_equal "service", @tactic.instance_variable_get("@_resource")
    assert_equal nil, @tactic.instance_variable_get("@_port")
    assert_equal "localhost", @tactic.instance_variable_get("@_destination")
    assert_equal "localhost", @tactic.instance_variable_get("@_domain")
  end

  def test_requirements
    # Setup magic variables
    @tactic.send(:set_the_magic_variables, "service@domain:8080")
    # Resource = service
    # Domain = domain
    # Destination = domain:8080
    # Port = 8080

    res = @tactic.send(:requirements, ["tcp_out@Local"]).first
    assert_equal "tcp_out@node_name", res

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

    @tactic.execute "unit_testing@local:8080"

    truth_source = "unit_testing_truth"

    truth = "a_truth"
    value = "truth_value"
    @tactic.send(:pass_on_truth, truth, truth_source, value)

    other_truth = "other_truth"
    other_value = "other_truth_value"
    @tactic.send(:pass_on_truth, other_truth, truth_source, other_value)

    @tactic.tick

    sleep(1)

    # The test_unit tactic should have changed the source of the truth
    # to be itself. We therefore have to make sure the original truth source
    # is not the same as the tactic name
    name = @tactic.instance_variable_get("@_name")
    assert truth_source != name, 
        "Tactic name should not be the same as original truth source"

    # The test unit will have passed the truth back into the solver
    truths = @solver.truths

    assert_is_true truths, truth, name, value
    assert_is_true truths, other_truth, name, other_value

    @tactic.shut_down
  end

  def test_pass_on_requesting_user
    # This is a very roundabout kind of test
    # The unit_test tactic passes all truths it receives back
    # as a new truth.
    # In order to test it, we therefore pass some truths on to the tactic,
    # and verify that they appear in the solver as truths

    @tactic.execute "unit_testing@local:8080"

    truth_source = "params"

    truth = "user"
    value = @user_info

    @tactic.tick

    sleep(1)

    # The test_unit tactic should have changed the source of the truth
    # to be itself. We therefore have to make sure the original truth source
    # is not the same as the tactic name
    name = @tactic.instance_variable_get("@_name")
    assert truth_source != name, 
        "Tactic name should not be the same as original truth source"

    # The test unit will have passed the truth back into the solver
    truths = @solver.truths

    assert_is_true truths, truth, name, value

    @tactic.shut_down
  end

  def test_tactic_expresses_needs
    # This test relies on the unit test tactic expression
    # a certain need. The need is then tested for in the 
    # solver

    @tactic.execute "unit_testing@local:8080"
    sleep(2)

    name = @tactic.instance_variable_get("@name")

    # The test unit will have passed the truth back into the solver
    needs = @solver.needs
    assert_needs needs, "unit_test_need@local:8080"
    assert_needs needs, "unit_test_need@domainA"
    assert_needs needs, "unit_test_need@domainB:30"
    assert_needs needs, "unit_test_need@domainC:40"
  end

  # The tactics should be able to contribute truths back to the solver
  def test_add_truth
    truth = "a_truth"
    value = "truth_value"
    @tactic.send(:add_truth, truth, value, @user_info)
    other_truth = "other_truth"
    other_value = "other_truth_value"
    @tactic.send(:add_truth, other_truth, other_value, @user_info)
    @tactic.tick
    sleep(1)

    truths = @solver.truths
    pp truths.to_a
    name = @tactic.instance_variable_get("@_name")

    assert_is_true truths, truth, name, value
    assert_is_true truths, other_truth, name, other_value
  end

  # The requirement should be added to the main solver
  def test_add_requirement
    truth = "truth_type"
    other_truth = "other_truth_type_needed"
    @tactic.send(:add_requirement, truth)
    @tactic.send(:add_requirement, other_truth)
    sleep(0.1) # UGLY! We need to wait so that the data can propagate through bud
    data = @solver.needs
    assert_needs data, truth
    assert_needs data, other_truth
  end

  def test_execute_unsupported_resource
    # The unit test thing should support
    # - unit_testing@local:8080
    #
    # It requires
    # - test_cause@Local 
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
    # The unit test tactic should support
    # - unit_testing@local:8080
    #
    # It requires
    # - test_cause@Local 
    # - test_Destination@Destination 
    # - test_Port@local
    # - test_Domain@local:Port
    # - test_Resource@Destination

    @tactic.execute "unit_testing@local:8080"
    sleep(1)

    # The unit_test tactic passes all its truths back to
    # the main repo.
    # Check that we got it back.
    np = @solver.needs
    assert_needs np, "test_cause@node_name"
    assert_needs np, "test_local:8080@local:8080"
    assert_needs np, "test_8080@local"
    assert_needs np, "test_local@local:8080"
    assert_needs np, "test_unit_testing@local:8080"
    @tactic.shut_down
  end

  def test_need_from_data
    @tactic.execute "unit_testing@local:8080"
    sleep(1)

    d = {"what" => "hello"}
    assert_equal "hello@local:8080", @tactic.send(:need_from, d),
        "Should default to the same destination"

    d = {"what" => "hello", "destination" => "awesome:80"}
    assert_equal "hello@awesome:80", @tactic.send(:need_from, d)

    d = {"what" => "hello", "domain" => "kle.io"}
    assert_equal "hello@kle.io", @tactic.send(:need_from, d)

    d = {"what" => "hello", "port"=>3}
    assert_equal "hello@local:3", @tactic.send(:need_from, d),
        "Should default to the same domain, if domain isn't given"

    d = {"what" => "hello", "domain" => "kle.io", "port"=>3}
    assert_equal "hello@kle.io:3", @tactic.send(:need_from, d)
  end

private
  def assert_is_true p, what, source, value
    assert_equal 1, (p.to_a.select {|t| 
      data = t[2]
      t[0] == what and
      t[1] == source and
      data[0] == value
    }).size, "Should have a truth for #{what}"
  end

  def assert_needs p, what
    assert_equal 1, (p.to_a.select {|t| t[0] == what}).size,
        "Should have #{what} added as a need"
  end
end
