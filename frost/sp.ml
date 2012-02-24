(* This module declares general system wide types *)

type name = string
type ip = string
type port = int64
type srv = SRV of ip * port

type addressable =
  | IPAddressInstance of ip
  | SRVInstance of srv

type signalling_channel =
  | SignallingChannel of ip * port
  | NoSignallingChannel

module type TacticSig = sig
  val name : unit -> string
  (* val provides : unit -> channel_property list *)
  val connect : name -> name -> unit Lwt.t
end

let iprecord ip = IPAddressInstance(ip)
let srvrecord ip port = SRVInstance(SRV(ip, port))
