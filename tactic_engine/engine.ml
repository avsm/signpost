let paths_for_req pos_cons req = 
  (* return all the paths that have all the requirements satisfied *)
  List.filter (fun (_, props) ->
    (* check that all the required requirements
     * are part of what is provided *)
    let unsatisfied_reqs = List.filter (fun r -> not (List.mem r props)) req in
    (* if there are unsatisfied requirements then we do not wan't to use it *)
    unsatisfied_reqs = []) pos_cons

let connect_nodes nodeA nodeB possible_connections requirements =
  let connections_we_can_use = paths_for_req possible_connections requirements in
  List.iter (fun (tactics, props) ->
    (* Setup connections *)
    try 
      let nodeA_addressable = List.hd(nodeA.Sp.ips) in
      let nodeB_addressable = List.hd(nodeB.Sp.ips) in
      let acc = (nodeA_addressable, nodeB_addressable) in
      let (addrA, addrB) = List.fold_right (fun t (addrA, addrB) ->
        let module Tactic = (val t : Sp.TacticSig) in
        (Tactic.connect (nodeA, addrA) (nodeB, addrB))
      ) tactics acc in

      Printf.printf "Connected node %s to node %s (using %s)" 
          nodeA.Sp.name nodeB.Sp.name (Utils.output_line_from_conn_option tactics props)

    with Sp.TacticFailed -> ()) connections_we_can_use

let _ = 
  let ip_addressable = Sp.IPAddressInstance(Sp.IP("0.0.0.0", "Initial")) in
  let nodeA = Sp.create_node "laptop" [ip_addressable] in
  let nodeB = Sp.create_node "home" [ip_addressable] in
  let nodeC = Sp.create_node "work" [ip_addressable] in
  let possible_connections = Stackability.possible_connections () in

  (* try to connect two nodes *)
  let reqs = [Sp.Authentication] in
  Printf.printf "\nWill attempt to connect two machines:\n";
  connect_nodes nodeA nodeB possible_connections reqs

