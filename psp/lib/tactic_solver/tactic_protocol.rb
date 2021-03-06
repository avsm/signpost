module TacticProtocol
  state do
    channel :needed_truth # Used by the tactic solver to provide a truth to the tactic
    channel :need_truth # Used by the tactic to indicate the need of a truth
    channel :observe_truth # Used by a tactic or daemon when it wants to become an observer
    channel :provide_truth # Used by the tactic to provide a truth
    channel :remove_subscriptions # Used by tactic when terminating to unsubscribe

    # Format of data on the wire
    scratch :needed_truth_scratch, [:what, :provider, :user_info, :signpost] => [:truth]
    scratch :need_truth_scratch, [:what, :who, :signpost] => [:user_info, :who_name]
    scratch :observe_truth_scratch, [:what, :who, :signpost] => [:user_info, :who_name]
    scratch :provide_truth_scratch, [:what, :provider, :user_info, :signpost] => [:truth, :ttl]
    scratch :remove_subscriptions_scratch, [:who]
  end
end
