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

(* Signalling HTTP server that runs over Iodine *)
open Lwt
open Printf
open Cohttp

module Resp = struct
  (* respond with an error *)
  let not_found req err =
    let status = `Not_found in
    let headers = [ "Cache-control", "no-cache" ] in
    let resp = sprintf "<html><body><h1>Error</h1><p>%s</p></body></html>" err in
    let body = [`String resp] in
    Response.init ~body ~headers ~status ()

  (* internal error *)
  let internal_error err =
    let status = `Internal_server_error in
    let headers = [ "Cache-control", "no-cache" ] in
    let resp = sprintf "<html><body><h1>Internal Server Error</h1><p>%s</p></body></html>" err in
    let body = [`String resp] in
    Response.init ~body ~headers ~status ()

  (* dynamic response *)
  let dyn req body =
    let status = `OK in
    let headers = [] in
    Response.init ~body ~headers ~status ()

  (* index page *)
  let index req =
    let body = [`String "Hello World"] in
    return (dyn req body)

  (* dispatch non-file URLs *)
  let dispatch req =
    function
    | []
    | ["index.html"]  ->
        index req
    | _ ->
        return (not_found req "dispatch")
end

(* main callback function *)
let dispatch conn_id req =
  let path = Cohttp.Request.path req in
  printf "HTTP: %s %s [%s]\n%!" (Common.string_of_method (Request.meth req)) path 
    (String.concat "," (List.map (fun (h,v) -> sprintf "%s=%s" h v) 
      (Request.params_get req)));
  let path_elem = Re_str.(split (regexp_string "/") path) in
  lwt resp = Resp.dispatch req path_elem in
  Cohttpd.Server.respond_with resp

let http_t () =
  let open Cohttpd.Server in
  let port = 8080 in
  let spec = { default_spec with callback=dispatch; port=port; auto_close=true } in
  main spec
