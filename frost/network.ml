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

open Graph

(**
  * The graph structure is an imperative unidirectional labelled graph,
  * with each node being an OrderedNode wrapper, and an edge representing
  * a single tactic. Multiple tactics are represented by multiple edges.
  *)
module G = Imperative.Digraph.ConcreteLabeled(Node.Ordered)(Node.FlowEntry)

(* Retrieve a network node by its name.
 * TODO: folding over the graph can be optimised
 *)
let find_node ~name g =
  G.fold_vertex (fun b a -> if b.Node.name = name then Some b else a) g None

(**
  * Extend the graph functor with enough to output a DOT graph of the
  * nodes and edges. 
  *)
module Display = struct
  include G
  let vertex_name v = "\"" ^ String.escaped (Node.node_to_string (V.label v)) ^ "\""
  let graph_attributes _ = []
  let default_vertex_attributes _ = []
  let vertex_attributes _ = []
  let default_edge_attributes _ = []
  let edge_attributes e = [`Label (Node.entry_to_string (E.label e)) ]
  let get_subgraph _ = None
end
module DotOutput = Graphviz.Dot(Display)

