(* Iodine tactic *)

let name () = "iodine"

let provides () = [Sp.Authentication; Sp.Bidirectional]

let check_inputs nodeA nodeB = match (nodeA, nodeB) with
      | Sp.IPAddressInstance(_), Sp.IPAddressInstance(_) -> 
            Sp.IPAddressInstance(Sp.IP("0.0.0.0", "Dummy")),
            Sp.IPAddressInstance(Sp.IP("0.0.0.0", "Dummy"))
      | a, b -> raise Sp.NonValidAddressables
