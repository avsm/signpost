(*
 * Copyright (c) 2012 Anil Madhavapeddy <anil@recoil.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

(* TODO better categorisation needed (wildcard matches, etc) *)
type service =
  | HTTP
  | IP (* of security option *)
  | TCP of port
  | UDP of port
  | Null

(**
  * Each node has a forwarding table for services, which describes how to
  * get to another node, and the distance to it.  It can be considered to
  * be an application-level BGP-style distance-vector routing table.
  **)
type node = {
  name: string;
  cap: cap;
  (* And any other metadata in the future goes here, such as the history of the
   * node for provenance information and debugging *)
}

type mode =
  | Active of unit Lwt.t       (* Flow is active *)
  | Failed of string           (* Flow permanently failed *)
  | Starting of mode Lwt.t     (* Flow is starting and will eventually either be active or failed *)
  | Stopped                    (* Flow is inactive *)
and entry = {
  id: int;                     (* Unique id for referring to this entry *)
  service: service;            (* Protocol method *)
  distance: int;               (* Distance vector *)
  mutable mode: mode;          (* State of the flow entry *)
  mutable depends: entry list; (* Other flow entries that depend on this on *)
}

let make_entry_id =
  let id = ref 0 in
  fun () -> incr id; !id

let make_entry ?(distance=1) ~service ~mode ~depends =
  let id = make_entry_id () in
  { id; service; distance; mode; depends}

let service_to_string =
  function
  | HTTP -> "HTTP"
  | IP -> "IP"
  | TCP port -> Printf.sprintf "TCP:%d" port
  | UDP port -> Printf.sprintf "UDP:%d" port
  | Null -> "Null"

let mode_to_string =
  function
  | Active t -> "active"
  | Failed r -> Printf.sprintf "failed(%s)" r
  | Starting t -> "starting"
  | Stopped -> "stopped"

let entry_to_string e =
  Printf.sprintf "%d: %s %d %s [%s]" e.id (service_to_string e.service)
    e.distance (mode_to_string e.mode)
    (String.concat "," (List.map (fun e -> string_of_int e.id) e.depends))

let make_node ?(cap=Enabled) ~name =
  { name; cap }

let node_to_string n =
  Printf.sprintf "%s (%s)" n.name
    (match n.cap with |Enabled -> "Enabled" |Dumb -> "Dumb")

(**
  * The OrderedNode module makes the node type into a COMPARABLE, with the
  * nodes ordered by its physical address, so name strings can be duplicates if
  * desired.
  *)
module Ordered = struct
  type t = node
  let compare (x:t) (y:t) = compare x y
  let hash (x:t) = Hashtbl.hash x.name
  let equal (x:t) (y:t) = x == y
end

module FlowEntry = struct
  type t = entry
  let compare x y = y.id - x.id
  let default = { id=(-1); service=Null; distance=0; mode=Failed ""; depends=[]}
end 
