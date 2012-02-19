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

(* The domain we are authoritative for *)
let our_domain =
  sprintf "d%d.%s" Config.signpost_number Config.domain

let our_iodine_domain =
  let d = "d" ^ (string_of_int Config.signpost_number) in
  [ "i"; d; Config.domain ]

(* Respond with an NXDomain if record doesnt exist *)
let nxdomain =
  return (Some { Dns.Query.rcode=`NXDomain; aa=false;
    answer=[]; authority=[]; additional=[] })

(* Figure out the response from a query packet and its question section *)
let get_response packet q =
  let open Dns.Packet in
  let module DQ = Dns.Query in
  (* Normalise the domain names to lower case *)
  let qnames = List.map String.lowercase q.q_name in
  (* First, check in the static zonefile trie if the domain is present *)
  let answer_from_trie = Dns.(Query.answer_query q.q_name q.q_type Loader.(state.db.trie)) in
  eprintf "answer_from_trie: %s\n%!" (string_of_rcode answer_from_trie.DQ.rcode);
  (* It's an NXDOMAIN, check if it is a dynamic DNS response, otherwise
   * use whatever came back from the trie *)
  match answer_from_trie.DQ.rcode with 
  |`NXDomain -> begin
    (* For this strawman, we assume a valid query has form
     * <src node>.<dst node>.<password>.<username>.<domain name>
     *)
    match qnames with
    |src::dst::password::user::domain -> begin
       let domain = String.concat "." domain in
       eprintf "src:%s dst:%s pass:%s user:%s dom:%s\n%!" src dst password user domain;
       answer_from_trie
    end
    |_ ->
       eprintf "TODO: issue unknown response\n%!";
       answer_from_trie
  end
  |_ -> answer_from_trie

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
  let daemon_t = join [ dns_t (); Signal.server_t () ] in
  Lwt_main.run daemon_t
