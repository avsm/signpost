require 'test_common'

class TestTacticHelpers < MiniTest::Unit::TestCase
  # should provide magic variables for problem description"
  def test_magic_variables_from
    res = TacticSolver::Helpers.magic_variables_from "service@localhost:8000"
    check_for res, "service", "localhost", 8000, "localhost:8000"

    res = TacticSolver::Helpers.magic_variables_from "tcp_out@homework.kle.io:834"
    check_for res, "tcp_out", "homework.kle.io", 834, "homework.kle.io:834"

    res = TacticSolver::Helpers.magic_variables_from "ip@default_name:1234"
    check_for res, "ip", "default_name", 1234, "default_name:1234"

    res = TacticSolver::Helpers.magic_variables_from "ip@crash-course"
    check_for res, "ip", "crash-course", nil, "crash-course"

    res = TacticSolver::Helpers.magic_variables_from "funky-resource_names.moha@crash-course"
    check_for res, "funky-resource_names.moha", "crash-course", nil, "crash-course"

    # It should raise expection for non-valid resource requirements
    assert_raises (TacticSolver::ResourceTypeException) do
      TacticSolver::Helpers.magic_variables_from ""
    end
  end

private
  def check_for res, service, domain, port, destination
    assert_equal service, res[:resource]
    assert_equal domain, res[:domain]
    assert_equal port, res[:port]
    assert_equal destination, res[:destination]
  end
end
