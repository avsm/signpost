(* Iodine tactic *)

let name () = "iodine"

let provides () = [Sp.Authentication; Sp.Bidirectional]

let check_stackability nodeA nodeB = match (nodeA, nodeB) with
      | Sp.IPAddressInstance(_), Sp.IPAddressInstance(_) -> 
            Sp.IPAddressInstance(Sp.IP("0.0.0.0", "Dummy")),
            Sp.IPAddressInstance(Sp.IP("0.0.0.0", "Dummy"))
      | a, b -> raise Sp.NonValidAddressables

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
 * Example RPCs being used
 *
 * - RunIodineServer
 *    Starts an iodine server, if one isn't running
 *    Returns: - The IP of the server in the iodine tunnel
 *             - The password used
 *
 * - ConnectToIodineServer
 *    Connects to a given iodine server
 *)
let connect a b =
  let (nodeA, addrA) = a in
  let (nodeB, addrB) = b in
  let nodeA_ch = nodeA.Sp.control_channel in
  let nodeB_ch = nodeB.Sp.control_channel in

  (* Have nodeB setup an iodine server *)
  let nodeB_response = do_rpc nodeB_ch (Sch.RPC("RunIodineServer")) (Sch.EmptyPayload) in
  let nodeA_response = do_rpc nodeA_ch (Sch.RPC("ConnectToIodineServer")) (Sch.Payload(["ip:UseAddrB"])) in
  (
    Sp.IPAddressInstance(Sp.IP("12.0.0.1", "iodine")), 
    Sp.IPAddressInstance(Sp.IP("12.0.0.2", "iodine"))
  )
