program = proxallium
compiler ?= gcc
compiler_flags = -Wall -I.
objects = allium.o

ifdef DEBUG
	compiler_flags += -g
else
	compiler_flags += -O2
endif

.PHONY: clean

$(program): $(program).c $(objects)
	$(compiler) $(compiler_flags) -o $(program) $(objects) $(program).c

allium.o: allium/allium.c
	$(compiler) -c "allium/allium.c"

clean:
	-rm $(program)
	-rm $(program).exe
	-rm *.o
