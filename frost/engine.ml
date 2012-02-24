(* This is an implementation of the tactics engine *)

open Lwt
open Printf

let tactics = [
    (module DirectConnection : Sp.TacticSig)
  ]

let iter_over_tactics a b =
  let open List in
  Lwt_list.iter_p (fun t ->
    let module Tactic = (val t : Sp.TacticSig) in
    Tactic.connect a b
  ) tactics

let connect a b =
  eprintf "Engine is trying to connect %s and %s\n" a b;
  iter_over_tactics a b
