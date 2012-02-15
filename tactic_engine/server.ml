open List

exception Invalid_addressables

(* IP's have two parts:
 * - The ip itself
 * - Who/what provides it. That could be local IP, or an IP provided by OpenVPN
 * etc.
 *)
type ip = IP of string * string

type port = Port of int

type srv = SRV of ip * port

(* TODO: Replace with whatever control channel we are using *)
type control_channel = ControlChannel of string

type addressable =
  | IPAddressInstance of ip
  | SRVInstance of srv

type goals = 
  | IPRecord
  | SRVRecord

type requirement =
  | Authentication
  | Encryption
  | Anonymity
  | Compression
  | Bidirectional

(* a node represents a control channel with which we 
 * can communicate with a node 
 *)
type node = {
  name : string;
  control_channel : control_channel;
  ips : addressable list;
}

type tactic = {
  tactic_name : string;
  (* The tactic function works as follows:
   * It takes three addressable units:
   * - Start point (A)
   * - End point (B)
   * - Relay node (R) (can be a random node, or either of the start or endpoint)
   * It returns
   * - addressable entity that B can use to see A
   * - addressable entity that A can use to see B
   *
   * We should only use relay nodes that we know can be used as relay nodes
   *)
  run : addressable -> addressable -> addressable -> (addressable * addressable);
  provides : requirement list
}

let (|>) a b = b a

let str_of_addr address = match address with
  | IPAddressInstance(IP(address, source)) -> address ^ " (" ^ source ^ ")"
  | SRVInstance(SRV(IP(address, source), Port(port))) -> address ^ ":" ^
        (string_of_int port) ^ " (" ^ source ^ ")"

let str_of_node node =
  let first_addressable = hd node.ips in
  str_of_addr first_addressable ^ " [" ^ node.name ^ "]"

let rec str_of_tactics tactics = match tactics with
  | [] -> "No tactics used"
  | tactic::[] -> tactic.tactic_name
  | tactic::rest -> tactic.tactic_name ^ " over " ^ (str_of_tactics rest)

let output_results tactics a b =
  let addr_a = str_of_node a in
  let addr_b = str_of_node b in
  let str_tac = str_of_tactics tactics in
  Printf.printf "Found connection %s -> %s (%s)\n" addr_a addr_b str_tac

let does_tactic_provide_reqs tactic reqs =
  try let _ = find (function req -> mem req tactic.provides) reqs in true
  with Not_found -> false

let tactics_providing_req reqs tactics =
  tactics
  |> filter (function tactic -> does_tactic_provide_reqs tactic reqs)

let already_has_tunnel a b =
  let addr_a, addr_b = hd a.ips, hd b.ips in
  match addr_a, addr_b with
  | IPAddressInstance(IP(_, "local")), IPAddressInstance(IP(_, "local")) -> false
  | _ -> true

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
type params = {
  start_node : node;
  end_node : node;
  nodes : node list;
  reqs : requirement list;
  tactics : tactic list;
  used_tactics : tactic list
}
let rec tactize params = match params.reqs with
  | [] -> output_results params.used_tactics params.start_node params.end_node
  | requirements ->
      params.tactics 
      |> tactics_providing_req requirements
      |> iter (fun tactic -> 
          make_permutations tactic params)

and make_permutations tactic params =
  let new_used_tactics = tactic :: params.used_tactics in
  let new_reqs = (filter (fun r -> not (mem r tactic.provides)) params.reqs) in
  let new_params = {params with used_tactics = new_used_tactics; reqs =
    new_reqs} in
  match (already_has_tunnel params.start_node params.end_node) with
  | true ->
      (* these nodes have a bidirectional link, so we don't have
       * to try to relay via a third party. Instead tell the tactic to relay
       * through the receiving end. *)
      execute_tactic params.start_node params.end_node params.end_node tactic new_params
  | false ->
      (* these nodes don't yet have a bidirectional link.
       * We therefore have to try all possible combos to 
       * hope we find a possible way of setting up a tunnel *)
      params.nodes 
      |> iter (fun node ->
          [(params.start_node, params.end_node);
           (params.end_node, params.start_node)]
          |> iter (function
              (* we don't want to relay through the starting node *)
              | (a,b) when a.name = node.name -> ()
              | (a,b) -> execute_tactic a b node tactic new_params))

and execute_tactic a b c tactic params = 
  let addr_a, addr_b, addr_c = (hd a.ips), (hd b.ips), (hd c.ips) in
  try
    let (new_a, new_b) = (tactic.run addr_a addr_b addr_c) in
    let updated_a = {a with ips = new_a :: a.ips} in
    let updated_b = {b with ips = new_b :: b.ips} in
    let updated_params = {params with 
                          start_node = updated_a; end_node = updated_b} in
    tactize updated_params
  with Invalid_addressables -> ()

let test () =
  (* Create the nodes we have in our system *)
  let node1 = {
    name = "seb";
    control_channel = ControlChannel("ChannelA");
    ips = [IPAddressInstance(IP("10.0.0.1", "local"))]
  } in
  let node2 = {
    name = "andrius";
    control_channel = ControlChannel("ChannelB");
    ips = [IPAddressInstance(IP("11.0.0.1", "local"))]
  } in
  let node3 = {
    name = "anil";
    control_channel = ControlChannel("ChannelC");
    ips = [IPAddressInstance(IP("12.0.0.1", "local"))]
  } in
  let nodes = [node1; node2; node3] in

  let reqs = [Bidirectional;Compression;Encryption] in

  (* Currently the following tactics exist *)
  let tactics = [
    {
      tactic_name = "OpenVPN"; 
      run = (fun addr_a addr_b addr_c -> match (addr_a, addr_b, addr_c) with
        | IPAddressInstance(a), IPAddressInstance(b), IPAddressInstance(c) -> 
              SRVInstance(SRV(IP("149.0.12.1", "OpenVPN"), Port(1332))),
              SRVInstance(SRV(IP("123.0.10.3", "OpenVPN"), Port(1193)))
        | _ -> raise Invalid_addressables);
      provides = [Authentication; Compression; Encryption;Bidirectional]
    };{
      tactic_name = "IPSec"; 
      run = (fun addr_a addr_b addr_c -> match (addr_a, addr_b, addr_c) with
        | IPAddressInstance(a), IPAddressInstance(b), IPAddressInstance(c) -> 
              IPAddressInstance(IP("209.0.123.1", "IPSec")),
              IPAddressInstance(IP("22.0.1.103", "IPSec"))
        | _ -> raise Invalid_addressables);
      provides = [Authentication; Encryption; Compression;Bidirectional]
    };{
      tactic_name = "TCPCrypt"; 
      run = (fun addr_a addr_b addr_c -> match (addr_a, addr_b, addr_c) with
        | SRVInstance(a), SRVInstance(b), SRVInstance(c) -> 
              SRVInstance(SRV(IP("121.255.13.1", "TCPCrypt"), Port(1932))),
              SRVInstance(SRV(IP("191.12.100.103", "TCPCrypt"), Port(1200)))
        | _ -> raise Invalid_addressables);
      provides = [Encryption;Bidirectional]
    };{
      tactic_name = "Iodine"; 
      run = (fun addr_a addr_b addr_c -> match (addr_a, addr_b, addr_c) with
        | IPAddressInstance(a), IPAddressInstance(b), IPAddressInstance(c) -> 
              IPAddressInstance(IP("14.0.123.1", "Iodine")),
              IPAddressInstance(IP("18.0.1.103", "Iodine"))
        | _ -> raise Invalid_addressables);
      provides = [Authentication;Bidirectional]
    };{
      tactic_name = "Tor"; 
      run = (fun addr_a addr_b addr_c -> match (addr_a, addr_b, addr_c) with
        | IPAddressInstance(a), IPAddressInstance(b), IPAddressInstance(c) -> 
              SRVInstance(SRV(IP("14.0.123.1", "Tor"), Port(1332))),
              SRVInstance(SRV(IP("18.0.1.103", "Tor"), Port(1193)))
        | a, b, c -> raise Invalid_addressables);
      provides = [Anonymity;Bidirectional]
    }
  ] in

  (* setup params *)
  let params = {
    start_node = node1;
    end_node = node2;
    nodes = nodes;
    reqs = reqs;
    tactics = tactics;
    used_tactics = []
  } in
  (* Action GO! Find a way to connect the nodes :*)
  Printf.printf "%s wants to connect to %s\n" node1.name node2.name;
  tactize params

let _ =  test ()
