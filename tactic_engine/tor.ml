(* Tor tactic *)
let name () = "tor"

let provides () = [Sp.Anonymity; Sp.Bidirectional]

let check_inputs nodeA nodeB = match (nodeA, nodeB) with
      | Sp.IPAddressInstance(_), Sp.IPAddressInstance(_) -> 
            Sp.SRVInstance(Sp.SRV(Sp.IP("0.0.0.0", "Dummy"), Sp.Port(1111))),
            Sp.SRVInstance(Sp.SRV(Sp.IP("0.0.0.0", "Dummy"), Sp.Port(1111)))
      | a, b -> raise Sp.NonValidAddressables
