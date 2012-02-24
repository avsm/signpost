(* This module stores connections between devices. *)

open Lwt
open Printf

(* (node name * node name) -> (IP address * IP address) *)
(* let connections = Hashtbl.create 1 *)

let find a b =
  eprintf "Finding existing connections between %s and %s\n" a b;
  eprintf "Trying to establish new ones\n";
  Engine.connect a b;
  Nodes.get_node_ip b
