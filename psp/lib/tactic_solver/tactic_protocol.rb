module TacticProtocol
  state do
    channel :needed_truth # Used by the tactic solver to provide a truth to the tactic
    channel :need_truth # Used by the tactic to indicate the need of a truth
    channel :provide_truth # Used by the tactic to provide a truth

    # Format of data on the wire
    scratch :need_truth_scratch, [:what, :who] => [:who_name]
    scratch :needed_truth_scratch, [:what, :provider] => [:truth]
    scratch :provice_truth_scratch, [:what, :provider] => [:truth]
  end
end
