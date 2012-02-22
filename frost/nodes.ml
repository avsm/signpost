(* This module deals with operations that have to do with nodes. *)

open Printf

type node = {
  signalling_channel: Sp.ip;
  name: Sp.name
}

(* node name -> Sp.node *)
let nodes = Hashtbl.create 1

let update name node =
  Hashtbl.replace nodes name node

let new_node_with_name name sig_ch =
  {
    name = name;
    signalling_channel = sig_ch
  }

let update_sig_channel name sig_channel =
  try
    let node = (Hashtbl.find nodes name) in
    update name {node with signalling_channel = sig_channel}
  with Not_found ->
    update name (new_node_with_name name sig_channel)

let get_ip name =
  let node = (Hashtbl.find nodes name) in
  node.signalling_channel

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

(* It seems this is needed in order to have the compiler understand
 * the type of the hash table... nasty stuff. *)
let testing = 
  let name = "me" in
  let me = {
    name = name;
    signalling_channel = "127.0.0.1"
  } in
  update name me
