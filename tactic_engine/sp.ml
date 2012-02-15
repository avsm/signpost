(* Types ***********************************************************)
type ip = IP of string * string

type port = Port of int

type srv = SRV of ip * port

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
  control_channel : Sch.t;
  ips : addressable list;
}

exception NonValidAddressables

module type TacticSig = sig
  val name : unit -> string
  val check_stackability : addressable -> addressable -> addressable * addressable
  val provides : unit -> channel_property list
end
