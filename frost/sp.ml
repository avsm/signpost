(* This module declares general system wide types *)

type name = string
type ip = string
type port = int
type srv = SRV of ip * port

type addressable =
  | IPAddressInstance of ip
  | SRVInstance of srv

type signalling_channel =
  | SignallingChannel of ip
  | NoSignallingChannel
