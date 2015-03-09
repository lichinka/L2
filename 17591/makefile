#include ./make.inc
include ./make.dom

all: proxy



proxy: proxy.o
	$(CC) proxy.o $(LDOPTS) $(OPTS) $(LIBDIR) $(LIB) $(INC) -o proxy


#.SUFFIXES: .c .cpp .cu .o

%.o : %.c
	echo $(OBJ)
	$(CC) $(OPTS) $(INC) -c $<


clean:
	echo *.o proxy 
	rm -f *.o proxy


.PHONY: clean

