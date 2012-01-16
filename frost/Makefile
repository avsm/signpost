.PHONY: all clean install build
all: build test doc

export OCAMLRUNPARAM=b

setup.bin: setup.ml
	ocamlopt.opt -o $@ $< || ocamlopt -o $@ $< || ocamlc -o $@ $<
	rm -f setup.cmx setup.cmi setup.o setup.cmo

setup.data: setup.bin
	./setup.bin -configure

build: setup.data setup.bin
	./setup.bin -build

doc: setup.data setup.bin
	./setup.bin -doc

test: setup.bin build
	./setup.bin -test

tmp.dot: build
	./_build/frost.native

tmp.ps: tmp.dot
	dot -Tps $< > $@

tmp.pdf: tmp.ps
	ps2pdf $< $@

clean:
	ocamlbuild -clean
	rm -f setup.data setup.log setup.bin
