open Lwt
open Printf
open Int64

let handle_rpc =
let open Rpc in function
  | None ->
      eprintf "warning: bad rpc\n%!";
      return ()
  | Some (Hello (node,ip, port)) ->
      eprintf "rpc: hello %s -> %s:%Li\n%!" node ip port;
      Nodes.update_sig_channel node ip port;
      return ()
