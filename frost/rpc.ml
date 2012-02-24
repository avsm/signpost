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

open Int64

type node_name = string
type ip = string
type port = int64

type command = string
type arg = string
type rpc_id =
  | Request of int64
  | Notification

type rpc = 
  | Hello of node_name * ip * port
  | RPC of command * arg list * rpc_id

let rpc_id_counter = ref 0

let rpc_to_json rpc =
  let open Json in
  Object [
    match rpc with
    | Hello (n, i, p) -> "hello", (Array [ String n; String i; Int p])
    | RPC (c, string_args, rpc_id) -> 
        let args = List.map (fun a -> String a) string_args in
        "rpc", (Object [
        ("method", String c);
        ("params", Array args);
        ("id", match rpc_id with
          | Request(id) -> Int id
          | Notification -> Null)
        ])
   ]

let rpc_of_json =
  let open Json in
  function
  | Object [ "hello", (Array [String n; String i; Int p]) ] ->
      Some (Hello (n,i, p))
  | Object [ "rpc", Object [
        ("method", String c);
        ("params", Array args);
        ("id", rpc_id)
      ]
    ] ->
      let string_args = List.map (fun (String s) -> s) args in
      let id = match rpc_id with
        | Null -> Notification
        | Int n -> Request(n) in
      Some(RPC(c, string_args, id))
  | _ -> None
 
let rpc_to_string rpc =
  Json.to_string (rpc_to_json rpc)

let rpc_of_string s =
  let json = try Some (Json.of_string s) with _ -> None in 
  match json with
  | None -> None
  | Some x -> rpc_of_json x

let fresh_id () =
  rpc_id_counter := !rpc_id_counter + 1;
  of_int !rpc_id_counter

let create_rpc method_name args =
  let id = Request (fresh_id ()) in
  RPC(method_name, args, id)

let create_notification method_name args =
  RPC(method_name, args, Notification)
