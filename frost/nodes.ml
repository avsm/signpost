(* This module deals with operations that have to do with nodes. *)

open Printf

(* node name -> IP address *)
let nodes = Hashtbl.create 1

let update name value =
  eprintf "Updating %s : %s\n%!" name value;
  Hashtbl.replace nodes name value

let get_ip name =
  Hashtbl.find nodes name

let testing = update "me" "127.0.0.1"

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
