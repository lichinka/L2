all: proxy

proxy: proxy.o
	$(CC) proxy.o $(LDOPTS) $(OPTS) $(LIBDIR) $(LIB) $(INC) -o proxy


#.SUFFIXES: .c .cpp .cu .o

%.o : %.c
	$(CC) $(OPTS) $(INC) -c $<

clean:
	rm -f *.o proxy

.PHONY: clean
