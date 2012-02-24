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
open Printf
open Sp_controller

(* The domain we are authoritative for *)
let our_domain =
  sprintf "d%d.%s" Config.signpost_number Config.domain

let our_domain_l =
  let d = "d" ^ (string_of_int Config.signpost_number) in
  [ d; Config.domain ]

(* Respond with an NXDomain if record doesnt exist *)
let nxdomain =
  return (Some { Dns.Query.rcode=`NXDomain; aa=false;
    answer=[]; authority=[]; additional=[] })

(* Ip address response for a node *)
let ip_resp ~dst ~src ~domain =
  let open Dns.Packet in
  let node_ip = Connections.find src dst in
  let node = {
    rr_name=dst::src::domain;
    rr_class=`IN;
    rr_ttl=0l;
    rr_rdata=`A node_ip;
  } in
  let answer = [ node ] in
  let authority = [] in
  let additional = [] in
  { Dns.Query.rcode=`NoError; aa=true; answer; authority; additional }

(* Figure out the response from a query packet and its question section *)
let get_response packet q =
  let open Dns.Packet in
  let module DQ = Dns.Query in
  (* Normalise the domain names to lower case *)
  let qnames = List.map String.lowercase q.q_name in
  eprintf "Q: %s\n%!" (String.concat " " qnames);
  let from_trie = Dns.(Query.answer_query q.q_name q.q_type Loader.(state.db.trie)) in
  match qnames with
    (* For this strawman, we assume a valid query has form
     * <dst node>.<src node>.<domain name>
     *)
  |dst::src::domain -> begin
     let domain'=String.concat "." domain in
     if domain' = our_domain then begin
       eprintf "src:%s dst:%s dom:%s\n%!" src dst domain';
       ip_resp ~dst ~src ~domain
     end else from_trie
  end
  |_ -> from_trie

let dnsfn ~src ~dst packet =
  let open Dns.Packet in
  match packet.questions with
  |[] -> eprintf "bad dns query: no questions\n%!"; return None
  |[q] -> return (Some (get_response packet q))
  |_ -> eprintf "dns dns query: multiple questions\n%!"; return None

let dns_t () =
  lwt fd, src = Dns_server.bind_fd ~address:"0.0.0.0" ~port:5354 in
  let zonebuf = sprintf "
$ORIGIN %s. ;
$TTL 0

@ IN SOA %s. hostmaster.%s. (
  2012011206      ; serial number YYMMDDNN
  28800           ; Refresh
  7200            ; Retry
  864000          ; Expire
  86400           ; Min TTL
)

@ A %s
i NS %s.
" our_domain Config.external_ip our_domain Config.external_ip Config.external_dns in
  eprintf "%s\n%!" zonebuf;
  Dns.Zone.load_zone [] zonebuf;
  Dns_server.listen ~fd ~src ~dnsfn

let _ =
  let daemon_t = join [ dns_t (); Signal.server_t (); 
        Sp_controller.listen () ] in
  Lwt_main.run daemon_t
