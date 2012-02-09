open Printf
open Unix
open Lwt
open Lwt_io
open Lwt_unix 
open Random
open Checksum
open Tcp

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

let gw_ip =  0x0a000202l
let gw_mac = "\x52\x54\x00\x12\x35\x02"
let local_ip = 0x0a00020fl
let local_mac = "\x08\x00\x27\xbb\x59\x1e"

type socks_proxy_ix = {
  src_port : int;
  dst_port : int;
  dst_ip : Nettypes.ipv4_addr;}

type sock_proxy_state = 
  | INIT                (* No packets yet send                  *)
  | SERVER_TCP_SYN      (* SYN packet was send to server        *)
  | SERVER_TCP_ESTAB    (* TCP established and SOCK req sent    *)
  | SERVER_SOCK_ESTAB   (* TCP Grant received and syn packet 
                        was send to client                      *)

let string_of_sock_proxy_state = function
      | INIT -> "INIT"
      | SERVER_TCP_SYN -> "SERVER_TCP_SYN"
      | SERVER_TCP_ESTAB -> "SERVER_TCP_ESTAB"
      | SERVER_SOCK_ESTAB -> "SERVER_SOCK_ESTAB"

type socks_proxy_data = {
  mutable state : sock_proxy_state;
  mutable src_isn : int32;
  mutable dst_isn : int32;
  dst_port : int;
  dst_ip : Nettypes.ipv4_addr;
}

type switch_state = {
(*   mutable mac_cache: (mac_switch, OP.Port.t) Hashtbl.t; *)
  mutable mac_cache: (OP.eaddr, OP.Port.t) Hashtbl.t; 
  mutable dpid: OP.datapath_id list;
  mutable of_ctrl: OC.state list;
  mutable socks_proxy_mapping : (int, socks_proxy_data) Hashtbl.t;
}

let string_of_socks_proxy_data state =
  (Printf.sprintf "state=%s, src_isn=%ld, dst_isn=%ld, dst_port=%d, dst_ip=%s" 
     (string_of_sock_proxy_state state.state) state.src_isn state.dst_isn
     state.dst_port (Nettypes.ipv4_addr_to_string state.dst_ip))


let switch_data = { 
  mac_cache = Hashtbl.create 0;
  dpid = []; 
  of_ctrl = []; socks_proxy_mapping = Hashtbl.create 0;} 

let get_tcp_sn data = 
  bitmatch data with 
    | {_:96:bitstring; 0x0800:16; 4:4; ihl:4; _:64:bitstring; 6:8; _:16; 
       _:64:bitstring; _:(ihl-5)*32:bitstring; _:32; isn:32;
       _:-1:bitstring } ->
        isn
    | { _ } -> invalid_arg("get_tcp_sn packet is not TCP")

let datapath_join_cb controller dpid evt =
  let dp = 
    match evt with
      | OE.Datapath_join c -> c
      | _ -> invalid_arg "bogus datapath_join event match!" 
  in
  switch_data.dpid <- switch_data.dpid @ [dp];
  return (pp "+ datapath:0x%012Lx\n%!" dp)

let handle_socks_proxy_trafic controller dpid m data buffer_id =
  let ix = 
    if (m.OP.Match.tp_src == 1080) then
      m.OP.Match.tp_dst
    else
      m.OP.Match.tp_src
  in
    Printf.printf "src port is %d src %d dst %d\n" ix m.OP.Match.tp_src m.OP.Match.tp_dst;
  let state = 
    if ( Hashtbl.mem switch_data.socks_proxy_mapping ix ) then (
      Printf.printf "state for ix %d found\n%!" ix;
       Hashtbl.find switch_data.socks_proxy_mapping ix
    ) else (
      Printf.printf "Generate new state for port %d\n%!" ix;
      {state=INIT; src_isn=0l; dst_isn=0l; dst_port=m.OP.Match.tp_dst; 
            dst_ip=(Nettypes.ipv4_addr_of_uint32 m.OP.Match.nw_dst);})
  in
    Printf.printf "state %s\n%!" (string_of_socks_proxy_data state);
    match state.state with
      | INIT -> 
          (* save the start isn, and send syn packet to sock *)
          let isn = get_tcp_sn data in 
            state.src_isn <- isn;
            state.state <- SERVER_TCP_SYN;
            (Printf.printf "received a new connection request with isn %lu (%s)\n"
               isn (string_of_socks_proxy_data state));
            Hashtbl.add switch_data.socks_proxy_mapping ix state;
            let pkt = Tcp.gen_server_syn data (Int32.sub isn 9l) 1080 m in 
            let bs = (OP.Packet_out.packet_out_to_bitstring 
                        (OP.Packet_out.create ~buffer_id:(-1l)
                           ~actions:[OP.(Flow.Output(OP.Port.Local , 2000))] 
                     ~data:pkt ~in_port:(OP.Port.No_port) () )) in  
              OC.send_of_data controller dpid bs
      | SERVER_TCP_SYN ->
          Printf.printf "Server connected, sending SYN+ACK and SOCKS request\n";
          (let isn = get_tcp_sn data in 
            state.dst_isn <- isn;
            state.state <- SERVER_TCP_ESTAB;
            let pkt = (Tcp.gen_server_ack (Int32.sub state.src_isn 8l) 
                        (Int32.add state.dst_isn 1l) m.OP.Match.tp_src ix m) in 
            let bs = (OP.Packet_out.packet_out_to_bitstring 
                        (OP.Packet_out.create ~buffer_id:(-1l)
                        ~actions:[OP.(Flow.Output(OP.Port.Local , 2000))] 
                        ~data:pkt ~in_port:(OP.Port.No_port) () )) in  
             lwt _ = OC.send_of_data controller dpid bs in 
             let sock_req = (BITSTRING{4:8; 1:8; state.dst_port:16; 
                                      state.dst_ip:32; "\x00":8:string}) in 
            let pkt = (Tcp.gen_tcp_data_pkt (Int32.sub state.src_isn 8l) 
                        (Int32.add state.dst_isn 1l) m.OP.Match.tp_src ix sock_req) in 
            let bs = (OP.Packet_out.packet_out_to_bitstring 
                        (OP.Packet_out.create ~buffer_id:(-1l)
                        ~actions:[OP.(Flow.Output(OP.Port.Local , 2000))] 
                        ~data:pkt ~in_port:(OP.Port.No_port) () )) in  
              OC.send_of_data controller dpid bs)
      | SERVER_TCP_ESTAB ->
          (* Filter out tcp ack packets with no payload *)
          (
          bitmatch (Tcp.get_tcp_packet_payload data) with 
            | {ver:8; res:8; _:16; _:32 } ->
                (if (res == 90) then (
                  state.state <- SERVER_SOCK_ESTAB;
                  Printf.printf "Server connection established\n%!";
                  (* Send server an ack to establish the connection *)
                  let pkt = (Tcp.gen_server_ack (Int32.add state.src_isn 1l)
                    (Int32.add state.dst_isn 9l) m.OP.Match.tp_src ix m) 
                  in
                  let bs = (OP.Packet_out.packet_out_to_bitstring 
                        (OP.Packet_out.create ~buffer_id:(-1l)
                        ~actions:[OP.(Flow.Output(OP.Port.Local , 2000))] 
                        ~data:pkt ~in_port:(OP.Port.No_port) () )) in  
                    lwt _ = OC.send_of_data controller dpid bs in
                    (* Setup appropriate flow in the switch*)
                  let actions = [
                    OP.Flow.Set_dl_src(gw_mac);
                    OP.Flow.Set_dl_dst(local_mac);
                    OP.Flow.Set_nw_src(gw_ip);
                    OP.Flow.Set_nw_dst(local_ip);
                    OP.Flow.Set_tp_dst(1080);
                    OP.Flow.Output(OP.Port.Local, 2000)] in
                  let m = (OP.Match.create_flow_match OP.Wildcards.exact_match
                    ~in_port:0xfffe ~dl_src:local_mac ~dl_dst:gw_mac
                    ~dl_type:0x0800 ~nw_tos:(char_of_int 0) ~nw_proto:(char_of_int 6)
                    ~nw_src:local_ip ~nw_dst:state.dst_ip 
                    ~tp_src:ix ~tp_dst:state.dst_port ()) in
                  let pkt = (OP.Flow_mod.create m 0_L OP.Flow_mod.ADD 
                    ~buffer_id:(-1) actions ()) in 
                  let bs = OP.Flow_mod.flow_mod_to_bitstring pkt in
                  let actions = [
                    OP.Flow.Set_dl_src(gw_mac);
                    OP.Flow.Set_dl_dst(local_mac);
                    OP.Flow.Set_nw_src(state.dst_ip);
                    OP.Flow.Set_nw_dst(local_ip);
                    OP.Flow.Set_tp_dst(ix);
                    OP.Flow.Set_tp_src(state.dst_port);
                    OP.Flow.Output(OP.Port.Local, 2000)] in
                  let m = (OP.Match.create_flow_match OP.Wildcards.exact_match
                    ~in_port:0xfffe ~dl_src:local_mac ~dl_dst:gw_mac
                    ~dl_type:0x0800 ~nw_tos:(char_of_int 0) ~nw_proto:(char_of_int 6)
                    ~nw_src:local_ip ~nw_dst:gw_ip 
                    ~tp_src:1080 ~tp_dst:ix ()) in
                  let pkt = (OP.Flow_mod.create m 0_L OP.Flow_mod.ADD 
                    ~buffer_id:(-1) actions ()) in 
                  let bs = (Bitstring.concat 
                    [bs; OP.Flow_mod.flow_mod_to_bitstring pkt;]) in
                  lwt _ = OC.send_of_data controller dpid bs in 
                 
                  (* Send SYN-ACK to client *)
                  let pkt = (Tcp.gen_server_synack (Int32.add state.dst_isn 8l) 
                    (Int32.add state.src_isn 1l) ix state.dst_port state.dst_ip) in 
                  let bs = (OP.Packet_out.packet_out_to_bitstring 
                    (OP.Packet_out.create ~buffer_id:(-1l)
                    ~actions:[OP.(Flow.Output(OP.Port.Local , 2000))] 
                    ~data:pkt ~in_port:(OP.Port.No_port) () )) in  
                    lwt _ = OC.send_of_data controller dpid bs in
                    return ()
                ) else 
                  return (Printf.printf "Sock proxy not granted\n%!")
                )
            | { _ } ->
                ((Bitstring.hexdump_bitstring Pervasives.stdout (Tcp.get_tcp_packet_payload data));
                return (Printf.printf "Probably some ACK was received, ignoring\n%!"))
          )
      | SERVER_SOCK_ESTAB -> return ()
          
let packet_in_cb controller dpid evt =
  let (in_port, buffer_id, data, dp) = 
    match evt with
      | OE.Packet_in (inp, buf, dat, dp) -> (inp, buf, dat, dp)
      | _ -> invalid_arg "bogus datapath_join event match!"
  in
  (* Parse Ethernet header *)
  let m = OP.Match.parse_from_raw_packet in_port data in

    (* transfer traffic to port 6000 - 6010 to port 5001 *)
    if ( (m.OP.Match.dl_type == 0x0800) && 
         (m.OP.Match.nw_proto == (char_of_int 6)) &&
         (m.OP.Match.tp_dst >= 6000) && (m.OP.Match.tp_dst <= 6010))  
    then (
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
    ) else (
          (* Move traffic to port 5001 to a random port between 6000 and 6010 *)
        if ( (m.OP.Match.dl_type == 0x0800) &&
         (m.OP.Match.nw_proto == (char_of_int 6)) &&
         (m.OP.Match.tp_dst == 5001))  then      
          ( let pkt = 
            match m.OP.Match.in_port with
              | OP.Port.Local ->
                  (OP.Packet_out.create
                     ~buffer_id:buffer_id 
                     ~actions:[
                       OP.(Flow.Set_tp_dst(6000 + (Random.int 10))); 
                       OP.(Flow.Output((OP.Port.port_of_int 1) , 2000))] 
                     ~data:data ~in_port:in_port ())   
              | _ ->
              invalid_arg((Printf.sprintf "Non registered Port %s" 
                             (OP.Port.string_of_port m.OP.Match.in_port)))
          in 
          let bs = OP.Packet_out.packet_out_to_bitstring pkt in  
            OC.send_of_data controller dpid bs
          ) else (
            if ( (m.OP.Match.dl_type == 0x0800) &&
                 (m.OP.Match.nw_proto == (char_of_int 6)) &&
                 ( (m.OP.Match.tp_dst == 80) || (m.OP.Match.tp_src == 80) 
                   ||  (m.OP.Match.tp_dst == 1080) || (m.OP.Match.tp_src == 1080)))  
            then (
              Printf.printf "Captured port 80 traffic\n%!";
              handle_socks_proxy_trafic controller dpid m data buffer_id 
            ) else (
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
            )
          )
    )

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
      Lwt_unix.setsockopt sock Unix.SO_REUSEADDR true;
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
