BIN  = test_bug_symm
OBJS = test_bug_symm.o

all: $(BIN)

$(BIN): $(OBJS)
	$(CXX) $(OBJS) $(LDOPTS) $(OPTS) $(LIBDIR) $(LIB) $(INC) -o $(BIN)

#.SUFFIXES: .c .cpp .cu .o

%.o : %.cpp
	$(CXX) $(OPTS) $(INC) -c $<

clean:
	rm -f $(OBJS) $(BIN)

.PHONY: clean
