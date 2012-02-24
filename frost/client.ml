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
open Int64

let node_name = ref "unknown"
let node_ip = ref "unknown"
let node_port = ref (of_int 0)

let sa = (Signal.Client.addr_from Config.iodine_node_ip (of_int Config.signal_port))

let usage () = eprintf "Usage: %s <node-name> <node-ip> <node-signalling-port>\n%!" Sys.argv.(0); exit 1

let client_t () =
  let hello_rpc = Rpc.Hello (!node_name, !node_ip, !node_port) in
  let xmit_t =
     while_lwt true do
       Signal.Client.send hello_rpc sa >>
       Lwt_unix.sleep 2.0
     done
  in
  xmit_t

let _ =
  (try node_name := Sys.argv.(1) with _ -> usage ());
  (try node_ip := Sys.argv.(2) with _ -> usage ());
  (try node_port := (of_int (int_of_string Sys.argv.(3))) with _ -> usage ());
  let daemon_t = join 
  [ 
    client_t (); 
    Signal.client_t ~port:!node_port
  ] in
  Lwt_main.run daemon_t
