(* Types ***********************************************************)
type ip = IP of string * string

type port = Port of int

type srv = SRV of ip * port

(* TODO: Replace with whatever control channel we are using *)
type control_channel = ControlChannel of string

type channel_property =
  | Authentication
  | Encryption
  | Anonymity
  | Compression
  | Bidirectional

type addressable =
  | IPAddressInstance of ip
  | SRVInstance of srv

type node = {
  name : string;
  control_channel : control_channel;
  ips : addressable list;
}

(* these need to be redefined and moved around *)
type rpc_function = string
type payload = Payload of string list
type rpc = RPC of node * rpc_function * payload

type tactic_return = 
  | Future of rpc list * callback
  | Link of node * node
  | TacticFailure

and callback = payload list -> tactic_return

exception NonValidAddressables

module type TacticSig = sig
  val name : unit -> string
  val check_inputs : addressable -> addressable -> addressable * addressable
  val provides : unit -> channel_property list
end
