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

type node_name = string
type ip = string

type rpc = 
  |Hello of node_name * ip


let rpc_to_json rpc =
  let open Json in
  Object [
    match rpc with
    |Hello (n,i) -> "hello", (Array [ String n; String i ])
   ]

let rpc_of_json =
  let open Json in
  function
  |Object [ "hello", (Array [String n; String i]) ] ->
     Some (Hello (n,i))
  |_ -> None
 
let rpc_to_string rpc =
  Json.to_string (rpc_to_json rpc)

let rpc_of_string s =
  let json = try Some (Json.of_string s) with _ -> None in 
  match json with
  |None -> None
  |Some x -> rpc_of_json x
