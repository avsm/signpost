open List

(* types for the different things you can request *)
type ip = 
  | IP of string

type port =
  | Port of int

type srv =
  | SRV of ip * port

(* a node represents a control channel with which we 
 * can communicate with a node 
 *)
type node =
  | Node of string

type addressable =
  | ControlChannelInstance of node
  | IPAddressInstance of ip
  | SRVInstance of srv

type goals = 
  | IPRecord
  | SRVRecord
  | ControlChannel

type requirement =
  | Authentication
  | Encryption
  | Anonymity
  | Compression

type tactic = {
  name : string;
  (* The tactic function works as follows:
   * It takes three addressable units:
   * - Start point (A)
   * - End point (B)
   * - Relay node (R) (can be a random node, or either of the start or endpoint)
   * It returns
   * - addressable entity that B can use to see A
   * - addressable entity that A can use to see B
   *)
  run : (addressable * addressable * addressable) -> (addressable * addressable);
  provides : requirement list
}

let (|>) a b = b a

let does_tactic_provide_reqs tactic reqs =
  try let _ = find (function req -> mem req tactic.provides) reqs in true
  with Not_found -> false

let tactics_providing_req reqs tactics =
  tactics
  |> filter (function tactic -> does_tactic_provide_reqs tactic reqs)

let str_of_addr a = match a with
  | ControlChannelInstance(Node(name)) -> name
  | IPAddressInstance(IP(address)) -> address
  | SRVInstance(SRV(IP(address), Port(port))) -> address ^ ":" ^ (string_of_int port)

let rec str_of_tactics tactics = match tactics with
  | [] -> "Used tactics:"
  | tactic::rest -> (str_of_tactics rest) ^ " > " ^ tactic.name

let output_results tactics a b =
  let addr_a = str_of_addr a in
  let addr_b = str_of_addr b in
  let str_tac = str_of_tactics tactics in
  Printf.printf "Found connection %s -> %s (%s)\n" addr_a addr_b str_tac

(*
 * This function takes a goal, a set of requirements, and a starting point.
 * It then tries as best as it can, to convert the starting point into something
 * satisfying all the requirements and that is the goal.
 *
 * More specifically:
 * - I have two names, A and B
 * I want:
 * - connectable ip of B
 * - the connection should be Encrypted
 * 
 * So goal:
 * - IP_address of B
 * Starting point:
 * - name of A 
 * - name of B
 * Requirements:
 * - Encrypted
 *)

let rec tactize goal (node_a, node_b) reqs nodes tactics used_tactics = match reqs with
  | [] -> output_results used_tactics node_a node_b
  | requirements ->
      tactics 
      |> tactics_providing_req requirements
      |> iter (function tactic -> 
          execute_tactic tactic goal (node_a, node_b) reqs nodes tactics used_tactics)

and execute_tactic tactic goal (node_a, node_b) reqs nodes tactics used_tactics = 
  let new_used_tactics = tactic :: used_tactics in
  let new_req = (filter (function r -> not (mem r tactic.provides)) reqs) in
  nodes 
  |> iter (function node ->
      [(node_a, node_b);(node_b, node_a)]
      |> iter (function (a,b) ->
          let (new_a, new_b) = tactic.run(a, b, node) in
          tactize goal (new_a, new_b) new_req nodes tactics new_used_tactics)
  )

let test () =
  let reqs = [Compression;Encryption] in
  let node1 = ControlChannelInstance(Node "Node A") in
  let node2 = ControlChannelInstance(Node "Node B") in
  let node3 = ControlChannelInstance(Node "Node C") in
  let nodes = [node1; node2; node3] in
  let tactics = [
    {
      name = "OpenVPN"; 
      run = (function a, b, c -> a, b); 
      provides = [Authentication; Compression; Encryption]
    };{
      name = "IPSec"; 
      run = (function a, b, c -> a, b);
      provides= [Authentication; Encryption]
    };{
      name = "TCPCrypt"; 
      run = (function a, b, c -> a, b);
      provides= [Encryption]
    };{
      name = "Iodine"; 
      run = (function a, b, c -> a, b);
      provides= [Authentication]
    };{
      name = "Tor"; 
      run = (function a, b, c -> a, b);
      provides= [Anonymity]
    }
  ] in
  tactize IPRecord (node1, node2) reqs nodes tactics []

let _ =  test ()
