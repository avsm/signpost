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
  (* Make some devices *)
  let cloud = Network.(make_node ~cap:Enabled ~name:"EC2") in
  let nat = Network.(make_node ~cap:Enabled ~name:"HomeNAT") in
  let iphone_3g = Network.(make_node ~cap:Dumb ~name:"iPhone3G") in
  let iphone_wifi = Network.(make_node ~cap:Dumb ~name:"iPhoneWifi") in
  let android_3g = Network.(make_node ~cap:Enabled ~name:"Android3G") in
  let android_wifi = Network.(make_node ~cap:Enabled ~name:"AndroidWifi") in
  let laptop = Network.(make_node ~cap:Enabled ~name:"Laptop") in
  (* And some connections between the devices *)
  let edges = Tactic.([
    nat, cloud, TCP;
    iphone_3g, cloud, OpenVPN;
    iphone_wifi, nat, TCP;
    android_3g, cloud, OpenVPN;
    android_wifi, nat, TCP;
    laptop, nat, SSL;
  ]) in
  (* Populate the graph *)
  List.iter (Network.G.add_vertex g)
    [ cloud; nat; iphone_3g; iphone_wifi; android_3g; android_wifi];
  List.iter (fun (src,dst,ty) ->
    let t = Tactic.make_tactic ty in
    let e = Network.G.E.create src t dst in
    Network.G.add_edge_e g e
  ) edges;
  (* Dump it out in DOT format *)
  let oc = open_out "tmp.dot" in
  Network.DotOutput.output_graph oc g;
  close_out oc;
  g

let _ = test ()
