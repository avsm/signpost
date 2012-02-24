(*
 * Copyright (c) 2005-2012 Anil Madhavapeddy <anil@recoil.org>
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

open Lwt
open Lwt_unix
open Printf

let resolve t = Lwt.on_success t (fun _ -> ())

module OP = Ofpacket
module OC = Controller
module OE = OC.Event

let pp = Printf.printf
let sp = Printf.sprintf

(* TODO this the mapping is incorrect. the datapath must be moved to the key
 * of the hashtbl *)
type mac_switch = {
  addr: OP.eaddr; 
  switch: OP.datapath_id;
}

type switch_state = {
(*   mutable mac_cache: (mac_switch, OP.Port.t) Hashtbl.t; *)
  mutable mac_cache: (OP.eaddr, OP.Port.t) Hashtbl.t; 
  mutable dpid: OP.datapath_id list;
  mutable of_ctrl: OC.state list; 
}

let switch_data = { mac_cache = Hashtbl.create 0;
                    dpid = []; 
                    of_ctrl = [];
                  } 


let datapath_join_cb controller dpid evt =
  let dp = 
    match evt with
      | OE.Datapath_join c -> c
      | _ -> invalid_arg "bogus datapath_join event match!" 
  in
  switch_data.dpid <- switch_data.dpid @ [dp];
  return (pp "+ datapath:0x%012Lx\n" dp)

let req_count = (ref 0)

let add_entry_in_hashtbl mac_cache ix in_port = 
  if not (Hashtbl.mem mac_cache ix ) then
      Hashtbl.add mac_cache ix in_port
  else  
      Hashtbl.replace mac_cache ix in_port 

let packet_in_cb controller dpid evt =
incr req_count;
  let (in_port, buffer_id, data, dp) = 
    match evt with
      | OE.Packet_in (inp, buf, dat, dp) -> (inp, buf, dat, dp)
      | _ -> invalid_arg "bogus datapath_join event match!"
  in
  (* Parse Ethernet header *)
  let m = OP.Match.parse_from_raw_packet in_port data in 

  (* save src mac address *)
  let ix = m.OP.Match.dl_src in
    add_entry_in_hashtbl switch_data.mac_cache ix in_port;
 
  (* check if I know the output port in order to define what type of message
   * we need to send *)
    let ix = m.OP.Match.dl_dst in
      if ( (OP.eaddr_is_broadcast ix)
        || (not (Hashtbl.mem switch_data.mac_cache ix)) ) 
      then (
        let pkt = OP.Packet_out.create
                    ~buffer_id:buffer_id ~actions:[ OP.(Flow.Output(Port.All , 2000))] 
                    ~data:data ~in_port:in_port () 
        in
        let bs = OP.Packet_out.packet_out_to_bitstring pkt in 
          OC.send_of_data controller dpid bs
      (*     Printf.fprintf switch_data.log "%d %f\n" (!req_count) (((OS.Clock.time ()) -. ts)*.1000000.0) *)
      ) else (
        let out_port = (Hashtbl.find switch_data.mac_cache ix) in
        let actions = [OP.Flow.Output(out_port, 2000)] in
        let pkt = OP.Flow_mod.create m 0_L OP.Flow_mod.ADD 
                    ~buffer_id:(Int32.to_int buffer_id)
                    actions () in 
        let bs = OP.Flow_mod.flow_mod_to_bitstring pkt in
          OC.send_of_data controller dpid bs
      )


(*let memory_debug () = 
   while_lwt true do
     (OS.Time.sleep 1.0)  >> 
     return (OC.mem_dbg "memory usage")
   done *)

(*let terminate_controller controller =
  while_lwt true do
    (OS.Time.sleep 60.0)  >>
    exit(1) *)
(*    return (List.iter (fun ctrl -> Printf.printf "terminating\n%!";
 *    (OC.terminate ctrl))  *)
(*  switch_data.of_ctrl)  *)
(*   done *)

let init controller = 
  if (not (List.mem controller switch_data.of_ctrl)) then
    switch_data.of_ctrl <- (([controller] @ switch_data.of_ctrl));
  pp "test controller register datapath cb\n";
  OC.register_cb controller OE.DATAPATH_JOIN datapath_join_cb;
  pp "test controller register packet_in cb\n";
  OC.register_cb controller OE.PACKET_IN packet_in_cb

let listen ?(port = 6633) () =
  try_lwt 
    let sock = Lwt_unix.socket Lwt_unix.PF_INET Lwt_unix.SOCK_STREAM 0 in
    lwt hostinfo = Lwt_unix.gethostbyname "localhost" in
    let _ = Printf.printf "Starting switch...\n%!" in 
    let server_address = hostinfo.Lwt_unix.h_addr_list.(0) in
      Lwt_unix.bind sock (Lwt_unix.ADDR_INET (server_address, port)); 
      Lwt_unix.listen sock 10; 
      Lwt_unix.setsockopt sock Unix.SO_REUSEADDR true;
      lwt () = Lwt_io.printl "Waiting for controller..." in 
      while_lwt true do 
        lwt (fd, sockaddr) = Lwt_unix.accept sock in
          match sockaddr with
            | ADDR_INET (dst, port) ->
              lwt () = Lwt_io.printl (Printf.sprintf 
                                        "Received a connection %s:%d"
                                      (Unix.string_of_inet_addr dst) port ) in
                let ip = 
                  match (Nettypes.ipv4_addr_of_string (Unix.string_of_inet_addr dst)) with
                    | None -> invalid_arg "dest ip is Invalid"
                    | Some(ip) -> ip
                in
                  Lwt_unix.set_blocking fd true;
                  Controller.listen fd (ip, port) init
            | ADDR_UNIX(_) -> invalid_arg "invalid unix addr"

      done
    with
      | e ->
          return (Printf.eprintf "Unexpected exception : %s" (Printexc.to_string e))

