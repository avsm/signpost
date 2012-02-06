(* 
 * Copyright (c) 2005-2011 Charalampos Rotsos <cr409@cl.cam.ac.uk>
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
open Lwt_list
open Lwt_unix
open Lwt_io
(* open Net *)
open Printexc 
open Bitstring
open Ofpacket


let sp = Printf.sprintf
let pr = Lwt_io.printl (* Printf.printf *) 
let ep = Lwt_io.printl (* Printf.eprintf *)
let cp = Lwt_io.printl (* OS.Console.log *) 

module OP = Ofpacket

let resolve t = Lwt.on_success t (fun _ -> ())

module Channel = struct 

  let write_bitstring t data =
(*     Printf.printf "sending bitstring of size %d\n"
 *     (Bitstring.bitstring_length data); *)
    (Lwt_unix.send t (Bitstring.string_of_bitstring data) 0 
      ((Bitstring.bitstring_length data)/8) [])

  let read_some ?(len=1500) t =
    let data = (String.create len) in 
    lwt a = (Lwt_unix.recv t data 0 len []) in
      return  (Bitstring.bitstring_of_string (String.sub data 0 a))

  let flush t =
    return ()
  
  let close t = 
    Lwt_unix.close t

end


module Event = struct
  type t = 
    DATAPATH_JOIN 
    | DATAPATH_LEAVE
    | PACKET_IN 
    | FLOW_REMOVED 
    | FLOW_STATS_REPLY 
    | AGGR_FLOW_STATS_REPLY 
    | DESC_STATS_REPLY 
    | PORT_STATS_REPLY 
    | TABLE_STATS_REPLY 
    | PORT_STATUS_CHANGE 

  type e = 
    | Datapath_join of OP.datapath_id
    | Datapath_leave of OP.datapath_id
    | Packet_in of OP.Port.t * int32 * Bitstring.t * OP.datapath_id
    | Flow_removed of
        OP.Match.t * OP.Flow_removed.reason * int32 * int32 * int64 * int64
      * OP.datapath_id 
    | Flow_stats_reply of int32 * bool * OP.Flow.stats list * OP.datapath_id
    | Aggr_flow_stats_reply of int32 * int64 * int64 * int32 * OP.datapath_id
    | Port_stats_reply of int32 * OP.Port.stats list *  OP.datapath_id
    | Table_stats_reply of int32 * OP.Stats.table list * OP.datapath_id 
    | Desc_stats_reply of
        string * string * string * string * string
      * OP.datapath_id
    | Port_status of OP.Port.reason * OP.Port.phy * OP.datapath_id

  let string_of_event = function
    | Datapath_join dpid -> sp "Datapath_join: dpid:0x%012Lx" dpid
    | Datapath_leave dpid -> sp "Datapath_leave: dpid:0x%012Lx" dpid
    | Packet_in (port, buffer_id, bs, dpid) 
      -> (sp "Packet_in: port:%s ... dpid:0x%012Lx buffer_id:%ld" 
            (OP.Port.string_of_port port) dpid buffer_id ) 
    | Flow_removed (flow, reason, duration_sec, duration_usec, 
                    packet_count, byte_count, dpid) 
      -> (sp "Flow_removed: flow: %s reason:%s duration:%ld.%ld packets:%s \
              bytes:%s dpid:0x%012Lx"
            (OP.Match.match_to_string flow) 
            (OP.Flow_removed.string_of_reason reason) 
            duration_sec duration_usec
            (Int64.to_string packet_count) (Int64.to_string byte_count) dpid)
    | Flow_stats_reply(xid, more, flows, dpid) 
      -> (sp "Flow stats reply: dpid:%012Lx more:%s flows:%d xid:%ld"
            dpid (string_of_bool more) (List.length flows) xid)
    | Aggr_flow_stats_reply(xid, packet_count, byte_count, flow_count, dpid)
      -> (sp "aggr flow stats reply: dpid:%012Lx packets:%Ld bytes:%Ld \
              flows:%ld xid:%ld" 
            dpid packet_count byte_count flow_count xid)
    | Port_stats_reply (xid, ports, dpid) 
      -> (sp "port stats reply: dpid:%012Lx ports:%d xid%ld" 
            dpid (List.length ports) xid)
    | Table_stats_reply (xid, tables, dpid) 
      -> (sp "table stats reply: dpid:%012Lx tables:%d xid%ld" 
            dpid (List.length tables) xid)
    | Desc_stats_reply (mfr_desc, hw_desc, sw_desc, serial_num, dp_desc, dpid)
      -> (sp "table stats reply: dpid:%012Lx mfr_desc:%s hw_desc:%s \
              sw_desc:%s serial_num:%s dp_desc:%s" 
            dpid mfr_desc hw_desc sw_desc serial_num dp_desc)
    | Port_status (r, ph, dpid) 
      -> (sp "post stats: port:%s status:%s dpid:%012Lx" ph.OP.Port.name
            (OP.Port.string_of_reason r) dpid)
end

type endhost = {
  ip: Nettypes.ipv4_addr;
  port: int;
}

type of_socket  = {
    ch : Lwt_unix.file_descr;
    mutable buf : Bitstring.t;
}

type state = {
  mutable dp_db: (OP.datapath_id, of_socket) Hashtbl.t;
  mutable channel_dp: (endhost, OP.datapath_id) Hashtbl.t;

  mutable datapath_join_cb: 
    (state -> OP.datapath_id -> Event.e -> unit Lwt.t) list;
  mutable datapath_leave_cb:
    (state -> OP.datapath_id -> Event.e -> unit Lwt.t) list;
  mutable packet_in_cb:
    (state -> OP.datapath_id -> Event.e -> unit Lwt.t) list;
  mutable flow_removed_cb:
    (state -> OP.datapath_id -> Event.e -> unit Lwt.t) list;
  mutable flow_stats_reply_cb:
    (state -> OP.datapath_id -> Event.e -> unit Lwt.t) list;
  mutable aggr_flow_stats_reply_cb:
    (state -> OP.datapath_id -> Event.e -> unit Lwt.t) list;
  mutable desc_stats_reply_cb:
    (state -> OP.datapath_id -> Event.e -> unit Lwt.t) list;
  mutable port_stats_reply_cb:
    (state -> OP.datapath_id -> Event.e -> unit Lwt.t) list;
  mutable table_stats_reply_cb:
    (state -> OP.datapath_id -> Event.e -> unit Lwt.t) list;
  mutable port_status_cb:
    (state -> OP.datapath_id -> Event.e -> unit Lwt.t) list;
}

let register_cb controller e cb =
  Event.(
    match e with 
      | DATAPATH_JOIN
        -> controller.datapath_join_cb <- controller.datapath_join_cb @ [cb]
      | DATAPATH_LEAVE 
        -> controller.datapath_leave_cb <- controller.datapath_leave_cb @ [cb]
      | PACKET_IN
        -> controller.packet_in_cb <- controller.packet_in_cb @ [cb]
      | FLOW_REMOVED
        -> controller.flow_removed_cb <- controller.flow_removed_cb @ [cb]
      | FLOW_STATS_REPLY 
        -> (controller.flow_stats_reply_cb
            <- controller.flow_stats_reply_cb @ [cb]
        )
      | AGGR_FLOW_STATS_REPLY 
        -> (controller.aggr_flow_stats_reply_cb 
            <- controller.aggr_flow_stats_reply_cb @ [cb]
        )
      | DESC_STATS_REPLY
        -> (controller.desc_stats_reply_cb
            <- controller.desc_stats_reply_cb @ [cb]
        )
      | PORT_STATS_REPLY 
        -> (controller.port_stats_reply_cb
            <- controller.port_stats_reply_cb @ [cb] 
        )
      | TABLE_STATS_REPLY
        -> (controller.table_stats_reply_cb
            <- controller.table_stats_reply_cb @ [cb])
      | PORT_STATUS_CHANGE
        -> controller.port_status_cb <- controller.port_status_cb @ [cb] 
  )

let process_of_packet state (remote_addr, remote_port) t ofp = 
  OP.(
    let ep = { ip=remote_addr; port=remote_port } in
    match ofp with
      | Hello (h, _) (* Reply to HELLO with a HELLO and a feature request *)
        -> (  
(*           Printf.printf "HELLO\n%!"; *)
            Channel.write_bitstring t (Header.build_h h) 
            >> Channel.write_bitstring t (build_features_req 0_l) 
            >> Channel.flush t
(*             >> return (Printf.printf "hello handler returned\n%!") *)
        )

      | Echo_req (h, bs)  (* Reply to ECHO requests *)
        -> ((* cp "ECHO_REQ"; *)
            Channel.write_bitstring t (build_echo_resp h bs)
            >> Channel.flush t
        )

      | Features_resp (h, sfs) (* Generate a datapath join event *)
        -> ((* cp "FEATURES_RESP";*)
            let dpid = sfs.Switch.datapath_id in
            let evt = Event.Datapath_join dpid in
            if not (Hashtbl.mem state.dp_db dpid) then (
                Hashtbl.add state.dp_db dpid {ch=t;
                buf=Bitstring.empty_bitstring;};
              Hashtbl.add state.channel_dp ep dpid
            );
            List.iter (fun cb -> resolve(cb state dpid evt)) state.datapath_join_cb;
            return ()
        )

      | Packet_in (h, p) (* Generate a packet_in event *) 
        -> ((* cp (sp "+ %s|%s" 
                  (OP.Header.string_of_h h)
                  (OP.Packet_in.string_of_packet_in p)); *)
            let dpid = Hashtbl.find state.channel_dp ep in
            let evt = Event.Packet_in (
              p.Packet_in.in_port, p.Packet_in.buffer_id,
              p.Packet_in.data, dpid) 
            in
             iter_s (fun cb -> cb state dpid evt)
                     state.packet_in_cb
(*             return ()  *)
        )
        
      | Flow_removed (h, p)
        -> ((* cp (sp "+ %s|%s" 
                  (OP.Header.string_of_h h)
                  (OP.Flow_removed.string_of_flow_removed p)); *)
            let dpid = Hashtbl.find state.channel_dp ep in
            let evt = Event.Flow_removed (
              p.Flow_removed.of_match, p.Flow_removed.reason, 
              p.Flow_removed.duration_sec, p.Flow_removed.duration_nsec, 
              p.Flow_removed.packet_count, p.Flow_removed.byte_count, dpid)
            in
            List.iter (fun cb -> resolve(cb state dpid evt)) state.flow_removed_cb;
            return ()
        )

      | Stats_resp(h, resp) 
        -> ((* cp (sp "+ %s|%s" (OP.Header.string_of_h h)
                  (OP.Stats.string_of_stats resp)); *)
            match resp with 
              | OP.Stats.Flow_resp(resp_h, flows) ->
                (let dpid = Hashtbl.find state.channel_dp ep in
                 let evt = Event.Flow_stats_reply(
                   h.Header.xid, resp_h.Stats.more_to_follow, flows, dpid) 
                 in
                 List.iter (fun cb -> resolve(cb state dpid evt)) 
                   state.flow_stats_reply_cb;
                 return ();
                )
                  
              | OP.Stats.Aggregate_resp(resp_h, aggr) -> 
                (let dpid = Hashtbl.find state.channel_dp ep in
                 let evt = Event.Aggr_flow_stats_reply(
                   h.Header.xid, aggr.Stats.packet_count, 
                   aggr.Stats.byte_count, aggr.Stats.flow_count, dpid) 
                 in
                 List.iter (fun cb -> resolve(cb state dpid evt)) 
                   state.aggr_flow_stats_reply_cb;
                 return ();
                )
                  
              | OP.Stats.Desc_resp (resp_h, aggr) ->
                (let dpid = Hashtbl.find state.channel_dp ep in
                 let evt = Event.Desc_stats_reply(
                   aggr.Stats.imfr_desc, aggr.Stats.hw_desc, 
                   aggr.Stats.sw_desc, aggr.Stats.serial_num, 
                   aggr.Stats.dp_desc, dpid) 
                 in
                 List.iter (fun cb -> resolve(cb state dpid evt)) 
                   state.desc_stats_reply_cb;
                 return ();
                )
                  
              | OP.Stats.Port_resp (resp_h, ports) ->
                (let dpid = Hashtbl.find state.channel_dp ep in
                 let evt = Event.Port_stats_reply(h.Header.xid, ports, dpid) 
                 in
                 List.iter (fun cb -> resolve(cb state dpid evt) )
                   state.port_stats_reply_cb;
                 return ();
                )
                  
              | OP.Stats.Table_resp (resp_h, tables) ->
                (let dpid = Hashtbl.find state.channel_dp ep in
                 let evt = Event.Table_stats_reply(h.Header.xid, tables, dpid)
                 in
                 List.iter (fun cb -> resolve(cb state dpid evt) )
                   state.table_stats_reply_cb;
                 return ();
                )

              | _ -> 
(*                   OS.Console.log "New stats response received";  *)
                  return ();
        ) 

      | Port_status(h, st) 
        -> ( (* cp (sp "+ %s|%s" (OP.Header.string_of_h h)
                  (OP.Port.string_of_status st)); *)
            let dpid = Hashtbl.find state.channel_dp ep in
            let evt = Event.Port_status (st.Port.reason, st.Port.desc, dpid) 
            in
            List.iter (fun cb -> resolve(cb state dpid evt)) state.port_status_cb;
            return () 
        )

      | _ -> 
(*           OS.Console.log "New packet received";  *)
          return () 
  )

let send_of_data controller dpid data = 
  let t = Hashtbl.find controller.dp_db dpid in
  Channel.write_bitstring t.ch data >> Channel.flush t.ch

let rec rd_data len t = 
  match len with
    | 0 -> return Bitstring.empty_bitstring
    | _ -> lwt data = (Channel.read_some ~len:len t) in 
           let nbytes = ((Bitstring.bitstring_length data)/8) in
           lwt more_data = (rd_data (len - nbytes) t) in
           return (Bitstring.concat [ data; more_data ])

let start = ref 0.0

let mem_dbg name =
  Gc.compact (); 
  let s = Gc.stat () in
  Printf.printf "blocks %s: l=%d f=%d \n %!" name s.Gc.live_blocks s.Gc.free_blocks

let terminate st = 
  Hashtbl.iter (fun _ ch -> resolve (Channel.close ch.ch) ) st.dp_db;
  Printf.printf "Terminating controller...\n"
   
let get_len_data data_cache len = 
  bitmatch (!data_cache) with
    | {ret:len*8:bitstring; buff:-1:bitstring} ->
            (data_cache := buff; 
(*              Printf.printf "reading %d bits\n%!" (len*8);   *)
         return ret)
    | { _ } -> raise Nettypes.Closed


let read_cache_data t data_cache len = 
     if ((Bitstring.bitstring_length (!data_cache)) < (len*8)) then
(*         lwt buf = (Channel.read_some t) in *)
        lwt buf = (Channel.read_some t) in
         data_cache := (Bitstring.concat [(!data_cache);
         buf; ]);
        get_len_data data_cache len
     else 
        get_len_data data_cache len

let check_data_size req ret = 
    if(req < ret ) then 
        Printf.printf "req: %d, rep: %d\n" req ret

let fetch_pdu fd data_cache =
  lwt hbuf = read_cache_data fd data_cache (OP.Header.get_len ) in
  let ofh  = OP.Header.parse_h hbuf in
  let dlen = ofh.OP.Header.len - OP.Header.get_len in 
  lwt dbuf = read_cache_data fd data_cache dlen in 
    return (OP.parse ofh dbuf)


let listen fd loc init =
  let st = { dp_db                    = Hashtbl.create 0; 
             channel_dp               = Hashtbl.create 0; 
             datapath_join_cb         = []; 
             datapath_leave_cb        = []; 
             packet_in_cb             = [];
             flow_removed_cb          = []; 
             flow_stats_reply_cb      = [];
             aggr_flow_stats_reply_cb = [];
             desc_stats_reply_cb      = []; 
             port_stats_reply_cb      = [];
             table_stats_reply_cb     = [];
             port_status_cb           = [];
           }
  in 
    init st;
    let data_cache = ref (Bitstring.empty_bitstring) in 
    
    let rec echo () =
    try_lwt
      while_lwt true do 
        fetch_pdu fd data_cache  >>=
        (process_of_packet st loc fd)
      done
    with
      | Nettypes.Closed -> return ();
      | OP.Unparsed(m, bs) 
      | OP.Unparsable(m, bs) -> Printf.printf "# unparsed! m=%s\n%!" m;
          (Printf.printf "exception bits size %d\n%!" 
             (Bitstring.bitstring_length bs));
            echo ()

          | Not_found ->  Printf.printf "Not found\n%!"; return ()
    in
      echo()
