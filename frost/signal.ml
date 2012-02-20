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

(* Signalling UDP server that runs over Iodine *)
open Lwt
open Printf


(* node name -> IP address *)
let nodes = Hashtbl.create 1

let testing = Hashtbl.replace nodes "me" "127.0.0.1"

(* in int32 format for dns. default to 0.0.0.0 *)
let get_node_ip name =
  let ipv4_addr_of_tuple (a,b,c,d) =
    let (+) = Int32.add in
    (Int32.shift_left a 24) +
    (Int32.shift_left b 16) +
    (Int32.shift_left c 8) + d
  in
  (* Read an IPv4 address dot-separated string *)
  let ipv4_addr_of_string x =
    let ip = ref 0l in
    (try Scanf.sscanf x "%ld.%ld.%ld.%ld"
      (fun a b c d -> ip := ipv4_addr_of_tuple (a,b,c,d));
    with _ -> ());
    !ip
  in
  let ip =
    try ipv4_addr_of_string (Hashtbl.find nodes name)
    with Not_found -> 0l
  in
  ip

let handle_rpc =
  let open Rpc in function
  |None ->
     eprintf "warning: bad rpc\n%!";
     return ()
  |Some (Hello (node,ip)) ->
     eprintf "rpc: hello %s -> %s\n%!" node ip;
     Hashtbl.replace nodes node ip;
     return ()

(* Listens on port Config.signal_port *)
let bind_fd ~address ~port =
  lwt src = try_lwt
    let hent = Unix.gethostbyname address in
    return (Unix.ADDR_INET (hent.Unix.h_addr_list.(0), port))
  with _ ->
    raise_lwt (Failure ("cannot resolve " ^ address))
  in
  let fd = Lwt_unix.(socket PF_INET SOCK_DGRAM 0) in
  let () = Lwt_unix.bind fd src in
  return fd

let sockaddr_to_string =
  function
  |Unix.ADDR_UNIX x -> sprintf "UNIX %s" x
  |Unix.ADDR_INET (a,p) -> sprintf "%s:%d" (Unix.string_of_inet_addr a) p

let server_t () =
  (* Listen for UDP packets *)
  lwt fd = bind_fd ~address:"0.0.0.0" ~port:Config.signal_port in
  while_lwt true do
    let buf = String.create 4096 in
    lwt len, dst = Lwt_unix.recvfrom fd buf 0 (String.length buf) [] in
    let subbuf = String.sub buf 0 len in
    eprintf "udp recvfrom %s : %s\n%!" (sockaddr_to_string dst) subbuf;
    let rpc = Rpc.rpc_of_string subbuf in
    handle_rpc rpc;
  done

