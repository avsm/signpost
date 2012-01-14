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

open Froc


let test () =
  let g = Network.G.create () in
  let cloud = { Network.name = "CLOUD" } in
  let nat = { Network.name = "NAT" } in
  let mobile = { Network.name = "MOBILE" } in
  Network.G.add_vertex g cloud;
  Network.G.add_vertex g nat;
  Network.G.add_vertex g mobile;
  let t1 = Tactic.({ name="Iodine"; ty=Iodine; mode=Off }) in
  let e1 = Network.G.E.create nat t1 cloud in
  Network.G.add_edge_e g e1;
  let t2 = Tactic.({ name="3G-VPN"; ty=TCP; mode=Off }) in
  let e2 = Network.G.E.create mobile t2 cloud in
  Network.G.add_edge_e g e2;
  let oc = open_out "tmp.dot" in
  Network.DotOutput.output_graph oc g;
  close_out oc;
  g

let _ = test ()
