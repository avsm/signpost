let name_from_tactic tactic =
  let module Tactic = (val tactic : Sp.TacticSig) in
  Tactic.name ()

(* find all tactic combinations that are possible *)
let build_static_tactic_tree available_tactics =
  let rec try_tactic ~tactics ~used_tactics ~properties ~results ~addr1 ~addr2 =
    (* At this point we have one more result, add it to the result list :*)
    let updated_results = (used_tactics, properties) :: results in
    (* itteratively run the next tactics, to create more diverse resutls *)
    List.fold_left (fun acc t -> 
      try 
        (* create a module for the given tactic *)
        let module Tactic = (val t : Sp.TacticSig) in
        (* see if the tactic would be able to run, given the inputs *)
        let na1, na2 = Tactic.check_inputs addr1 addr2 in
        (* we don't want to repeatedly use the same tactic, so remove it *)
        let tactics_except_this = List.filter (fun a -> 
          (name_from_tactic a) != (name_from_tactic t)) tactics in
        (* we now also have the properties of the tactic *)
        let props = (Tactic.provides ()) @ properties in
        (* and we want to remember having used an additional tactic *)
        let ut = t :: used_tactics in
        try_tactic 
            ~tactics: tactics_except_this
            ~used_tactics: ut
            ~properties: props
            ~results: acc
            ~addr1: na1 
            ~addr2: na2

      with Sp.NonValidAddressables -> acc) updated_results tactics

  in let foo_ip = Sp.IPAddressInstance(Sp.IP("0.0.0.0", "foo")) in
  try_tactic 
      ~tactics: available_tactics 
      ~used_tactics: [] 
      ~properties: [] 
      ~results: []
      ~addr1: foo_ip
      ~addr2: foo_ip


let output_options options = 
  let rec str_of_list conv delim things = match things with
    | [] -> "Dafack?"
    | thing::[] -> conv thing
    | thing::rest -> (conv thing) ^ delim ^ (str_of_list conv delim rest) in

  let prop_to_str = function
    | Sp.Authentication -> "Authentication"
    | Sp.Encryption -> "Encryption"
    | Sp.Anonymity -> "Anonymity"
    | Sp.Compression -> "Compression"
    | Sp.Bidirectional -> "Bidirectional" in

  List.iter (fun (tactics, properties) ->
    Printf.printf "(%s)" (str_of_list name_from_tactic " over " tactics);
    Printf.printf " provides properties: ";
    Printf.printf "%s\n" (str_of_list prop_to_str ", " properties);
  ) options

let _ = 
  let modules = [
    (module Iodine : Sp.TacticSig);
    (module Openvpn : Sp.TacticSig);
    (module Tor : Sp.TacticSig)
  ] in
  Printf.printf "We have found the following options:\n";
  let possible_connections = build_static_tactic_tree modules in
  output_options possible_connections
