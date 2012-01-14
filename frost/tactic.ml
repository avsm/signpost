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

(**
  * A tactic sets up a single, uni-directional point-to-point link.
  *)

(**
  * The type of a tactic represents how it performs its route setup. For now,
  * we just maintain a static list here, although this will eventually be 
  * more dynamic.
  *)
type ty =
  | TCP
  | OpenVPN
  | SSH
  | Iodine
  | Null

(**
  * A tactic instance is represented by an Lwt thread and a state indicating if
  * it is currently active or not (or being established)
  *)
type mode =
  | Off
  | Starting of mode Lwt.t
  | Established of mode Lwt.t
  | Stopping of mode Lwt.t

(**
  * Overall state descriptor for a tactic instance.
  **)
type t = {
  name: string;
  mutable mode: mode;
  ty: ty;
}

let compare x y =
  String.compare x.name y.name

let default =
  { name = "???"; mode=Off; ty=Null }

(**
  * Convert a tactic state to a human-readable string
  *)
let to_string t =
  Printf.sprintf "{ %s (%s) %s }" t.name
    (match t.mode with
     |Off -> "Off"
     |Starting _ -> "Starting"
     |Established _ -> "Established"
     |Stopping _ -> "Stopping"
    )
    (match t.ty with
      |TCP -> "TCP" 
      |OpenVPN -> "OpenVPN" 
      |SSH -> "SSH"
      |Iodine -> "Iodine"
      |Null -> "Null"
    )

