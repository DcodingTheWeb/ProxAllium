program = proxallium
compiler ?= gcc
compiler_flags = -O2 -Wall -I.
objects = allium.o

$(program): $(program).c $(objects)
	$(compiler) $(compiler_flags) -o $(program) $(objects) $(program).c

allium.o: allium/allium.c
	$(compiler) -c "allium/allium.c"
