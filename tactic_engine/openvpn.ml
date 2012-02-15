(* OpenVPN tactic *)

let name () = "OpenVPN"

let provides () = 
    [Sp.Authentication; Sp.Bidirectional; Sp.Encryption; Sp.Compression]

let check_stackability nodeA nodeB = match (nodeA, nodeB) with
      | Sp.IPAddressInstance(_), Sp.IPAddressInstance(_) -> 
            Sp.SRVInstance(Sp.SRV(Sp.IP("0.0.0.0", "Dummy"), Sp.Port(1111))),
            Sp.SRVInstance(Sp.SRV(Sp.IP("0.0.0.0", "Dummy"), Sp.Port(1111)))
      | a, b -> raise Sp.NonValidAddressables


(* ******************************************
 * Try to setup an OpenVPN tunnel
 * ******************************************)

let do_rpc ch rpc payload = 
  match (Sch.invoke_rpc 
      ~channel: ch 
      ~rpc: rpc
      ~payload: payload) with
    | Sch.Success(response) -> response
    | Sch.Failure(err) -> 
        Printf.printf "%s failed with %s\n" (name ()) err;
        raise Sp.TacticFailed
    | Sch.Timeout -> 
        Printf.printf "%s timed out\n" (name ());
        raise Sp.TacticFailed

(* 
 * TODO: Implement something more sensible
 *)
let connect a b =
  let (nodeA, addrA) = a in
  let (nodeB, addrB) = b in
  let nodeA_ch = nodeA.Sp.control_channel in
  let nodeB_ch = nodeB.Sp.control_channel in
  let _ = do_rpc nodeB_ch (Sch.RPC("RunOpenVPNServer")) (Sch.EmptyPayload) in
  (
    Sp.SRVInstance(
      Sp.SRV(Sp.IP("12.0.0.1", "openvpn"), Sp.Port(1234))
    ),
    Sp.SRVInstance(
      Sp.SRV(Sp.IP("12.0.0.2", "openvpn"), Sp.Port(1203))
    )
  )
