open Lwt
open Printf
open Int64

let handle_rpc =
let open Rpc in function
  | None ->
      eprintf "warning: bad rpc\n%!";
      return ()
  | Some data -> begin
      match data with
      | Hello (node,ip, port) ->
          eprintf "rpc: hello %s -> %s:%Li\n%!" node ip port;
          Nodes.update_sig_channel node ip port;
          return ()
      | Response(Result r, _, id) -> begin
          eprintf "Response OK [%Li]: %s\n%!" id r;
          return ()
      end
      | Response(_, Error e, id) -> begin
          eprintf "Response ERROR [%Li]: %s\n%!" id e;
          return ()
      end
      | _ -> begin
          eprintf "ERROR: Received an RPC that clients don't handle\n%!";
          return ()
      end
  end
