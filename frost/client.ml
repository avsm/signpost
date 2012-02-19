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

open Lwt
open Printf

let node_name = ref "unknown"
let node_ip = ref "unknown"

let sa = Unix.(ADDR_INET (inet_addr_of_string Config.iodine_node_ip, Config.signal_port))

let usage () = eprintf "Usage: %s <node-name> <node-ip>\n%!" Sys.argv.(0); exit 1

let client_t =
  (try node_name := Sys.argv.(1) with _ -> usage ());
  (try node_ip := Sys.argv.(2) with _ -> usage ());
  let fd = Lwt_unix.(socket PF_INET SOCK_DGRAM 0) in
  let hello_rpc = Rpc.Hello (!node_name, !node_ip) in
  let buf = Rpc.rpc_to_string hello_rpc in
  let xmit_t =
     while_lwt true do
       lwt len' = Lwt_unix.sendto fd buf 0 (String.length buf) [] sa in
       eprintf "sent [%d]: %s\n%!" len' buf;
       Lwt_unix.sleep 2.0
     done
  in
  xmit_t

let _ = Lwt_unix.run client_t
