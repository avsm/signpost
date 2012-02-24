open Lwt
open Printf

let handle_rpc =
  let open Rpc in begin function
  | None ->
      eprintf "warning: bad rpc\n%!";
      return ()
  | Some data ->
      match data with
        | Hello (node, ip, port) -> begin
            eprintf "rpc: hello %s -> %s:%Li\n%!" node ip port;
            return ()
        end
        | RPC(command, arg_list, rpc_id) -> begin
            let args = String.concat ", " arg_list in
            match rpc_id with
            | Rpc.Notification ->
                eprintf "NOTIFICATION: %s with args %s\n%!" command args;
                return ()
            | Rpc.Request id ->
                eprintf "REQUEST: %s with args %s (ID: %Li)\n%!" 
                    command args id;
                return ()
        end
  end
