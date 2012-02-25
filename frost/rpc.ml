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
type id = int64
type result = 
  | Result of string
  | NoResult
type error = 
  | Error of string
  | NoError

type rpc = 
  | Hello of node_name * ip * port
  | Request of command * arg list * id
  | Notification of command * arg list
  | Response of result * error * id

let rpc_id_counter = ref 0

let rpc_to_json rpc =
  let open Json in
  Object [
    match rpc with
    | Hello (n, i, p) -> "hello", (Array [ String n; String i; Int p])
    (* Based on the specifications of JSON-RPC:
     * http://json-rpc.org/wiki/specification *)
    | Request (c, string_args, id) -> 
        let args = List.map (fun a -> String a) string_args in
        "request", (Object [
          ("method", String c);
          ("params", Array args);
          ("id", Int id)
        ])
    | Notification (c, string_args) -> 
        let args = List.map (fun a -> String a) string_args in
        "notification", (Object [
          ("method", String c);
          ("params", Array args);
          ("id", Null)
        ])
    (* When there was an error, the result must be nil *)
    | Response (_r, Error e, id) -> 
        "response", (Object [
          ("result", Null);
          ("error", String e);
          ("id", Int id)
        ])
    (* When there is a result, the error has to be nil *)
    | Response (Result r, _e, id) -> 
        "response", (Object [
          ("result", String r);
          ("error", Null);
          ("id", Int id)
        ])
   ]

let rpc_of_json =
  let open Json in
  function
  | Object [ "hello", (Array [String n; String i; Int p]) ] ->
      Some (Hello (n,i, p))
  | Object [ "request", Object [
        ("method", String c);
        ("params", Array args);
        ("id", Int id)
      ]
    ] ->
      let string_args = List.map (fun (String s) -> s) args in
      Some(Request(c, string_args, id))
  | Object [ "notification", Object [
        ("method", String c);
        ("params", Array args);
        ("id", Null)
      ]
    ] ->
      let string_args = List.map (fun (String s) -> s) args in
      Some(Notification(c, string_args))
  | Object [ "response", Object [
        ("result", String result);
        ("error", Null);
        ("id", Int id)
      ]
    ] ->
      Some(Response(Result result, NoError, id))
  | Object [ "response", Object [
        ("result", Null);
        ("error", String e);
        ("id", Int id)
      ]
    ] ->
      Some(Response(NoResult, Error e, id))
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
  let id = fresh_id () in
  Request(method_name, args, id)

let create_notification method_name args =
  Notification(method_name, args)

let create_response_ok result id =
  Response(Result result, NoError, id)

let create_response_error error id =
  Response(NoResult, Error error, id)
