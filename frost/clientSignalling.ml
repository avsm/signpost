open Lwt
open Printf

let handle_rpc =
  let open Rpc in begin function
  | None ->
      eprintf "warning: bad rpc\n%!";
      return ()
  | Some data ->
      match data with
      | Request(command, arg_list, id) -> begin
          let args = String.concat ", " arg_list in
          eprintf "REQUEST: %s with args %s (ID: %Li)\n%!" command args id;
          return ()
      end
      | Notification(command, arg_list) -> begin
          let args = String.concat ", " arg_list in
          eprintf "NOTIFICATION: %s with args %s\n%!" command args;
          return ()
      end
      | _ -> begin
          eprintf "ERROR: Received an RPC that clients don't handle\n%!";
          return ()
      end
  end
