type t = SignallingChannel of string

(* Should be spec'ed out. What is an RPC exactly in our case? *)
type rpc = RPC of string

type payload = Payload of string list

(* these need to be redefined and moved around *)
type rpc_response =
  | Success of string
  | Failure of string
  | Timeout

let channel_name channel = channel

let invoke_rpc channel rpc payload : rpc_response =
  Printf.printf "Making RPC call through signalling channel to node %s\n"
      (channel_name channel);
  Failure("Not implemented")
