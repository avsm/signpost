(* Direct connetion tactic *)
open Lwt
open Printf
open Int64

let name () = "Direct connection"

(* ******************************************
 * Try to establish if a direct connection between two hosts is possible
 * ******************************************)

let connect a b =
  (* Now, for fun, send a reply *)
  let send_hello () =
    try 
      let ip, port = Nodes.signalling_channel b in
      let sa = (Signal.Server.addr_from ip port) in
      let rpc = Rpc.create_rpc "get_local_ips" [] in
      Signal.Server.send rpc sa >>
      let rpc = Rpc.create_rpc "try_connecting_to" ["foo"] in
      Signal.Server.send rpc sa >>
      let notification = Rpc.create_notification "test" ["foo";"bar"] in
      Signal.Server.send notification sa
    with Not_found -> return () in
  send_hello () >>= (fun () ->
    eprintf "DirectConnection trying to establish connection between %s and %s\n" a b;
    return ())
