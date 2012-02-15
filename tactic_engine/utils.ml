let name_from_tactic tactic =
  let module Tactic = (val tactic : Sp.TacticSig) in
  Tactic.name ()

let rec str_of_list conv delim things = match things with
  | [] -> "Dafack?"
  | thing::[] -> conv thing
  | thing::rest -> (conv thing) ^ delim ^ (str_of_list conv delim rest)

let prop_to_str = function
  | Sp.Authentication -> "Authentication"
  | Sp.Encryption -> "Encryption"
  | Sp.Anonymity -> "Anonymity"
  | Sp.Compression -> "Compression"
  | Sp.Bidirectional -> "Bidirectional"

let output_line_from_conn_option tactics properties =
  "(" ^ (str_of_list name_from_tactic " over " tactics) ^ ") "
      ^ " provides properties: " ^ (str_of_list prop_to_str ", " properties)

let output_options options = 
  List.iter (fun (tactics, properties) ->
    Printf.printf "%s\n" (output_line_from_conn_option tactics properties)
  ) options
