module TacticProtocol
  state do
    channel :eval_tactic_request
    channel :tactic_evaluation_result
    channel :tactic_signup
    channel :failed_evaluation_result
  end
end
