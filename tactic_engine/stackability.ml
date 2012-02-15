(* find all tactic combinations that are possible *)
let build_static_tactic_tree available_tactics =
  let rec try_tactic ~tactics ~used_tactics ~properties ~results ~addr1 ~addr2 =
    (* returns a list of properties that a tactic provides, that are not 
     * already provided *)
    let non_provided_properties t props = 
      let module Tactic = (val t : Sp.TacticSig) in
      let tactic_provides = (Tactic.provides ()) in
      List.filter (fun req -> not (List.mem req properties)) tactic_provides in

    (* the tactics that provides at least one property that is not already provided *)
    let fresh_tactics = List.filter (fun t ->
      (non_provided_properties t properties) <> []) tactics in

    (* At this point we have one more result, add it to the result list :*)
    let updated_results = (used_tactics, properties) :: results in
    (* itteratively run the next tactics, to create more diverse resutls *)
    List.fold_left (fun acc t -> 
      try 
        (* create a module for the given tactic *)
        let module Tactic = (val t : Sp.TacticSig) in
        (* see if the tactic would be able to run, given the inputs *)
        let na1, na2 = Tactic.check_stackability addr1 addr2 in
        (* we don't want to repeatedly use the same tactic, so remove it *)
        let tactics_except_this = List.filter (fun a -> 
          (Utils.name_from_tactic a) <> (Utils.name_from_tactic t)) tactics in
        (* we now also have the properties of the tactic *)
        let props = (non_provided_properties t properties) @ properties in
        (* and we want to remember having used an additional tactic *)
        let ut = t :: used_tactics in
        try_tactic 
            ~tactics: tactics_except_this
            ~used_tactics: ut
            ~properties: props
            ~results: acc
            ~addr1: na1 
            ~addr2: na2

      with Sp.NonValidAddressables -> acc) updated_results fresh_tactics

  in let foo_ip = Sp.IPAddressInstance(Sp.IP("0.0.0.0", "foo")) in
  try_tactic 
      ~tactics: available_tactics 
      ~used_tactics: [] 
      ~properties: [] 
      ~results: []
      ~addr1: foo_ip
      ~addr2: foo_ip


let possible_connections () =
  let modules = [
    (module Iodine : Sp.TacticSig);
    (module Openvpn : Sp.TacticSig);
    (module Tor : Sp.TacticSig)
  ] in
  let possible_connections = List.filter (function
    | ([], []) -> false
    | _ -> true) (build_static_tactic_tree modules) in
  Utils.output_options possible_connections;
  possible_connections
