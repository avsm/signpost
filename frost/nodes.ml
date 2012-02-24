(* This module deals with operations that have to do with nodes. *)

open Printf
open Int64

type node = {
  signalling_channel: Sp.signalling_channel;
  name: Sp.name
}

(* node name -> Sp.node *)
let nodes = Hashtbl.create 1

let new_node_with_name name = {
  name = name;
  signalling_channel = Sp.NoSignallingChannel
}

let update name node =
  Hashtbl.replace nodes name node

let get name = 
  try (Hashtbl.find nodes name)
  with Not_found -> (new_node_with_name name)

let update_sig_channel name channel_ip port =
  let node = get name in
  let sch = Sp.SignallingChannel(channel_ip, port) in
  update name {node with signalling_channel = sch}

let get_ip name =
  let node = get name in
  match node.signalling_channel with
    | Sp.NoSignallingChannel -> raise Not_found
    | Sp.SignallingChannel(ip, _port) -> ip

(* in int32 format for dns. default to 0.0.0.0 *)
let get_node_ip name =
  let ipv4_addr_of_tuple (a,b,c,d) =
    let (+) = Int32.add in
    (Int32.shift_left a 24) +
    (Int32.shift_left b 16) +
    (Int32.shift_left c 8) + d
  in
  (* Read an IPv4 address dot-separated string *)
  let ipv4_addr_of_string x =
    let ip = ref 0l in
    (try Scanf.sscanf x "%ld.%ld.%ld.%ld"
      (fun a b c d -> ip := ipv4_addr_of_tuple (a,b,c,d));
    with _ -> ());
    !ip
  in
  let ip =
    try ipv4_addr_of_string (get_ip name)
    with Not_found -> 0l
  in
  ip

let signalling_channel name =
  let node = get name in
  match node.signalling_channel with
  | Sp.NoSignallingChannel -> raise Not_found
  | Sp.SignallingChannel(ip, port) -> (ip, port)
  

(* It seems this is needed in order to have the compiler understand
 * the type of the hash table... nasty stuff. *)
let testing = 
  let name = "me" in
  let me = {
    name = name;
    signalling_channel = Sp.SignallingChannel("127.0.0.1", (of_int 4444))
  } in
  update name me
