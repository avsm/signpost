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

let test () =
  let g = Network.G.create () in
  (* Make some devices *)
  let cloud = Node.(make_node ~cap:Enabled ~name:"EC2") in
  let nat = Node.(make_node ~cap:Enabled ~name:"HomeNAT") in
  let iphone_3g = Node.(make_node ~cap:Dumb ~name:"iPhone3G") in
  let iphone_wifi = Node.(make_node ~cap:Dumb ~name:"iPhoneWifi") in
  let android_3g = Node.(make_node ~cap:Enabled ~name:"Android3G") in
  let android_wifi = Node.(make_node ~cap:Enabled ~name:"AndroidWifi") in
  let laptop = Node.(make_node ~cap:Enabled ~name:"Laptop") in
  (* And some connections between the devices *)
  let edges = Tactic.([
    nat, cloud, TCP_connect 80;
    iphone_3g, cloud, OpenVPN ();
    iphone_wifi, nat, TCP_connect 80;
    android_3g, cloud, OpenVPN ();
    android_wifi, nat, UDP_ping (53,53);
    laptop, nat, Always_fail;
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

(**
  * The evaluation loop for the network should be: 

  *  - Request for A to connect B results in a calculation that pull in
  *    FROC behaviours when evaluating possible tactics. If any of these
  *    behaviours change in the future, it will trigger a recalculation of
  *    those tactics.
  *
  *  - When a node joins or leaves, this may also trigger a recalculation.
  *
  *  - Each tactic is an edge in the network, and has its own independent
  *    thread, and when it changes state, can also trigger a recalculation.
  *
  *  So, we have a graph of nodes/edges, and the main FRP
  *)
let _ = test ()
