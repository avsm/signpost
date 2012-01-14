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
  * A Signpost network has a set of nodes, each with unidirectional links pointing
  * to other nodes. The process of establishing, maintaining and expiring links is
  * handled via a push-based FRP framework.
  **)

type node = {
  name: string;
  (* And any other metadata in the future goes here, such as the history of the
   * node for provenance information and debugging *)
}

open Graph

(**
  * The OrderedNode module makes the node type into a COMPARABLE, with the
  * nodes ordered by its physical address, so name strings can be duplicates if
  * desired.
  *)
module OrderedNode = struct
  type t = node
  let compare (x:t) (y:t) = compare x y
  let hash (x:t) = Hashtbl.hash x.name
  let equal (x:t) (y:t) = x == y
end

(**
  * The graph structure is an imperative unidirectional labelled graph,
  * with each node being an OrderedNode wrapper, and an edge representing
  * a single tactic. Multiple tactics are represented by multiple edges.
  *)
module G = Imperative.Graph.ConcreteLabeled(OrderedNode)(Tactic)

(**
  * Extend the graph functor with enough to output a DOT graph of the
  * nodes and edges. 
  *)
module Display = struct
  include G
  let vertex_name v = "\"" ^ String.escaped (V.label v).name ^ "\""
  let graph_attributes _ = []
  let default_vertex_attributes _ = []
  let vertex_attributes _ = []
  let default_edge_attributes _ = []
  let edge_attributes e = [`Label (E.label e).Tactic.name]
  let get_subgraph _ = None
end
module DotOutput = Graphviz.Dot(Display)
