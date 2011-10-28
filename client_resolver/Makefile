all: resolve

resolve: resolve.c
	gcc -g -o resolve resolve.c ../unbound.svn/.libs/libunbound.so

clean: 
	rm -f resolve resolve.o *~
