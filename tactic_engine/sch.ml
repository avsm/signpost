type t = SignallingChannel of string

(* Should be spec'ed out. What is an RPC exactly in our case? *)
type rpc = RPC of string

type payload = 
  | Payload of string list
  | EmptyPayload

(* these need to be redefined and moved around *)
type rpc_response =
  | Success of string
  | Failure of string
  | Timeout

let channel_name channel = 
  let SignallingChannel(name) = channel in
  name

let establish_channel nodeName = 
    SignallingChannel("Signalling channel for " ^ nodeName)

let invoke_rpc ~channel ~rpc ~payload : rpc_response =
  Printf.printf "Making RPC call through '%s'\n" (channel_name channel);
  Failure("Not implemented")
