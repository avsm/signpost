(* OpenVPN tactic *)

let name () = "OpenVPN"

let provides () = 
    [Sp.Authentication; Sp.Bidirectional; Sp.Encryption; Sp.Compression]

let check_inputs nodeA nodeB = match (nodeA, nodeB) with
      | Sp.IPAddressInstance(_), Sp.IPAddressInstance(_) -> 
            Sp.SRVInstance(Sp.SRV(Sp.IP("0.0.0.0", "Dummy"), Sp.Port(1111))),
            Sp.SRVInstance(Sp.SRV(Sp.IP("0.0.0.0", "Dummy"), Sp.Port(1111)))
      | a, b -> raise Sp.NonValidAddressables
