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

(**
  * A tactic sets up a single, uni-directional point-to-point link.
  * Every tactic has an entry in the Node forwarding table, where its
  * state is maintained.
  *)

open Lwt

type src_port = int
type dst_port = int

type openvpn_state = unit (* TODO *)
type ipsec_state = unit (* TODO *)
type tactic =
  | TCP_connect of dst_port
  | Always_fail (* for testing *)
  | HTTP_connect 
  | UDP_ping of src_port * dst_port
  | OpenVPN of openvpn_state
  | IPSec of ipsec_state

 
(* Attempt a TCP connect out to dst:port *) 
module TCP_connect = struct

  (* Right now, it just always connects after some pausing, and regularly
     outputs to the console *) 
  let start ~src ~dst ~port = 
    let th = 
      Printf.printf "TCP_connect: starting %s -> %s:%d\n%!" src dst port;
      lwt () = Lwt_unix.sleep 3.0 in
      let t,_ = Lwt.task () in
      let cont = ref true in
      Lwt.on_cancel t (fun () -> cont := false);
      let ping_t =
        while_lwt !cont do
          Printf.printf "TCP_connect: %s -> %s:%d OK\n%!" src dst port;
          Lwt_unix.sleep 5.0
        done
      in
      return (Node.Active ping_t)
    in
    Node.TCP port, th
end

(* Tactic that always fails for debugging *)
module Always_fail = struct
  let start ~src ~dst =
    let th = 
      lwt () = Lwt_unix.sleep 2.0 in
      return (Node.Failed "always_fail")
    in
    Node.Null, th
end

let start_tactic ~src ~dst ~tactic =
  let service, th =
    match tactic with
    | TCP_connect port -> TCP_connect.start ~src ~dst ~port
    | Always_fail -> Always_fail.start ~src ~dst
  in
  let mode = Node.Starting th in
  let depends = [] in (* eventually an FRP dependency for recalculation *)
  Node.make_entry ~service ~mode ~depends

