
(* TACTICS *********************************************************)
class tactic_base tactic what_is_provided = object
  method provides = what_is_provided
  method connect a b : node -> node -> tactic_return = (tactic a b)#connect
end

(* 1) IODINE *******************************************************)
class iodine = object
  inherit tactic_base [Authentication;Bidirectional] (fun nodeA nodeB ->
    object
      method connect = 
        Printf.printf "Iodine tries to connect %s -> %s\n" nodeA.name nodeB.name;
        TacticFailure
    end
  ) end


(* 2) OpenVPN ******************************************************)
(* similar implementation *)



(* Global state... ayayay ******************************************)
let workNode = {
  name = "Work";
  control_channel = ControlChannel "Work control channel";
  ips = []
}
let homeNode = {
  name = "Home";
  control_channel = ControlChannel "Home control channel";
  ips = []
}
let laptopNode = {
  name = "Laptop";
  control_channel = ControlChannel "Laptop control channel";
  ips = []
}
let nodes = [workNode;homeNode;laptopNode]
let tactics = [new iodine]


(* Functionality ***************************************************)
let does_tactic_provide_reqs tactic reqs =
  try let _ = find (function req -> mem req tactic#provides) reqs in true
  with Not_found -> false

let tactics_providing_req reqs =
  filter (function tactic -> does_tactic_provide_reqs tactic reqs) tactics

let reactor nodeA nodeB properties =
  let possible_tactics = tactics_providing_req properties in
  fold_left (fun a f -> (f#connect nodeA nodeB) :: a) [] possible_tactics

let connect nameA nameB properties = 
  try
    let nodeA = find (fun n -> n.name = nameA) nodes in
    let nodeB = find (fun n -> n.name = nameB) nodes in
    Printf.printf "Got the names of the nodes\n";
    reactor nodeA nodeB properties
  with Not_found -> 
    []


(* Ready, set, GO! *************************************************)
let _ = 
  let results = connect "Work" "Home" [Authentication] in
  iter (function 
    | Future _ -> Printf.printf "Got a future\n"
    | Link _ -> Printf.printf "Got a link\n"
    | TacticFailure -> Printf.printf "Got a tactic failure\n") results
