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
open Int64

module type SignallingHandlerSig = sig
  val handle_rpc : Rpc.rpc option -> unit Lwt.t
end

module Signalling (Handler : SignallingHandlerSig) = struct
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
    | Unix.ADDR_UNIX x -> sprintf "UNIX %s" x
    | Unix.ADDR_INET (a,p) -> sprintf "%s:%d" (Unix.string_of_inet_addr a) p

  let thread ~address ~port =
    (* Listen for UDP packets *)
    lwt fd = bind_fd ~address ~port in
    while_lwt true do
      let buf = String.create 4096 in
      lwt len, dst = Lwt_unix.recvfrom fd buf 0 (String.length buf) [] in
      let subbuf = String.sub buf 0 len in
      eprintf "udp recvfrom %s : %s\n%!" (sockaddr_to_string dst) subbuf;
      let rpc = Rpc.rpc_of_string subbuf in
      Handler.handle_rpc rpc;
    done

  let send_fd = Lwt_unix.(socket PF_INET SOCK_DGRAM 0)

  let send rpc dst =
    let buf = Rpc.rpc_to_string rpc in
    lwt len' = Lwt_unix.sendto send_fd buf 0 (String.length buf) [] dst in
    return (eprintf "sent [%d]: %s\n%!" len' buf)

  let addr_from ip port = 
    eprintf "Creating destiantion %s:%Ld\n" ip port;
    Unix.(ADDR_INET (inet_addr_of_string ip, (to_int port)))
end



(* 
 * Create signalling channel for server 
 *)
module Server = Signalling (ServerSignalling)

let server_t () =
  Server.thread ~address:"0.0.0.0" ~port:Config.signal_port


(* 
 * Create signalling channel for client 
 *)
module Client = Signalling (ClientSignalling)

let client_t ~port =
  (* For now, as a nasty hack, make the client signalling channel 
   * listen for datagrams at the server signalling channel port + 1 *)
  Client.thread ~address:"0.0.0.0" ~port:(to_int port)
