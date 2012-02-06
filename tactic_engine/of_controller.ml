open Printf
open Unix
open Lwt
open Lwt_io
open Lwt_unix 

let pp = Printf.printf
let sp = Printf.sprintf

module OC = Controller
module OP = Ofpacket
module OE = OC.Event

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

let packet_in_cb controller dpid evt =
  let (in_port, buffer_id, data, dp) = 
    match evt with
      | OE.Packet_in (inp, buf, dat, dp) -> (inp, buf, dat, dp)
      | _ -> invalid_arg "bogus datapath_join event match!"
  in
  (* Parse Ethernet header *)
  let m = OP.Match.parse_from_raw_packet in_port data in 
    if ( (m.OP.Match.dl_type == 0x0800) &&
         (m.OP.Match.nw_proto == (char_of_int 6)) &&
         (m.OP.Match.tp_dst <= 6000) &&
         (m.OP.Match.tp_dst <= 6010))  then
      let pkt = 
        match m.OP.Match.in_port with
          | OP.Port.Port(1) -> 
              (OP.Packet_out.create
                 ~buffer_id:buffer_id 
                 ~actions:[
                   OP.(Flow.Set_dl_dst("\x08\x00\x27\xbb\x59\x1e")); 
                   OP.(Flow.Set_tp_dst(5001)); 
                   OP.(Flow.Output(Port.Local, 2000))] 
                 ~data:data ~in_port:in_port ())
          | _ ->
              invalid_arg((Printf.sprintf "Non registered Port %s" 
                             (OP.Port.string_of_port m.OP.Match.in_port)))
      in
      let bs = OP.Packet_out.packet_out_to_bitstring pkt in  
        OC.send_of_data controller dpid bs 
    else
        if( (m.OP.Match.dl_type == 0x0800) &&
         (m.OP.Match.nw_proto == (char_of_int 6)) &&
         (m.OP.Match.tp_dst <= 5001))  then      
          let pkt = 
            match m.OP.Match.in_port with
              | OP.Port.Local ->
                  (OP.Packet_out.create
                     ~buffer_id:buffer_id 
                     ~actions:[
                       OP.(Flow.Set_tp_dst(6000 + (Random 10))); 
                       OP.(Flow.Output((OP.Port.port_of_int 1) , 2000))] 
                     ~data:data ~in_port:in_port ())   
              | _ ->
              invalid_arg((Printf.sprintf "Non registered Port %s" 
                             (OP.Port.string_of_port m.OP.Match.in_port)))
          in 
          let bs = OP.Packet_out.packet_out_to_bitstring pkt in  
            OC.send_of_data controller dpid bs               
        else 
              (* Push flow to install entries *) 
              let out_port = 
                match m.OP.Match.in_port with
                  |  OP.Port.Local ->  OP.Port.Port(1)
                  | OP.Port.Port(1) -> OP.Port.Local
                  | _ ->  invalid_arg((Printf.sprintf "Non registered Port %s" 
                                         (OP.Port.string_of_port m.OP.Match.in_port)))
              in
              let actions = [OP.Flow.Output(out_port, 2000)] in
              let pkt = OP.Flow_mod.create m 0_L OP.Flow_mod.ADD 
                          ~buffer_id:(Int32.to_int buffer_id)
                          actions () in 
              let bs = OP.Flow_mod.flow_mod_to_bitstring pkt in
                OC.send_of_data controller dpid bs

let init controller =
  if (not (List.mem controller switch_data.of_ctrl)) then
    switch_data.of_ctrl <- (([controller] @ switch_data.of_ctrl));
  pp "test controller register datapath cb\n";
  OC.register_cb controller OE.DATAPATH_JOIN datapath_join_cb;
  pp "test controller register packet_in cb\n";
  OC.register_cb controller OE.PACKET_IN packet_in_cb


lwt () =
  try_lwt 
    let sock = Lwt_unix.socket Lwt_unix.PF_INET Lwt_unix.SOCK_STREAM 0 in
    lwt hostinfo = Lwt_unix.gethostbyname "localhost" in
    lwt () = Lwt_io.printl "Hello world!!!" in 
    let server_address = hostinfo.Lwt_unix.h_addr_list.(0) in
      Lwt_unix.bind sock (Lwt_unix.ADDR_INET (server_address, 6633)); 
      Lwt_unix.listen sock 10; 
      lwt () = Lwt_io.printl "Socket is ready" in 
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
(*           Printexc.print_backtrace stderr; *)
