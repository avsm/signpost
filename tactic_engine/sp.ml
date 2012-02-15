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

(* This exception is raised when two tactics that cannot
 * be stacked are tested for stackability *)
exception NonValidAddressables

(* This exception is raised if a tactic doesn't succeed in executing
 * for any arbitrary reason. It halts the execution of tactics *)
exception TacticFailed

module type TacticSig = sig
  val name : unit -> string
  val check_stackability : addressable -> addressable -> addressable * addressable
  val provides : unit -> channel_property list
  val connect : node * addressable -> node * addressable -> 
      addressable * addressable
end

let create_node name ips =
  {
    name = name;
    control_channel = (Sch.establish_channel name);
    ips = ips
  }
