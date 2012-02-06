all:
	ocamlbuild -I openflow -use-ocamlfind -classic-display -tag 'syntax(camlp4o)' -package lwt.unix,lwt.syntax,bitstring,bitstring.syntax of_controller.native
clean:
	ocamlbuild -clean 
