CC=g++
CFLAGS= -std=c++11 -Wno-deprecated -O2
LDFLAGSOMP = -fopenmp
LDFLAGS=
CPPFLAGS= -I./include
all: vf3 vf3l vf3p
vf3:
	$(CC) $(CFLAGS) $(CPPFLAGS) -o bin/$@ main.cpp -DVF3 $(LDFLAGS)
vf3l:
	$(CC) $(CFLAGS) $(CPPFLAGS) -o bin/$@ main.cpp -DVF3L $(LDFLAGS)
vf3p:
	$(CC) $(CFLAGS) $(CPPFLAGS) -fopenmp -o bin/$@ main.cpp -DVF3P $(LDFLAGSOMP)
	$(CC) $(CFLAGS) $(CPPFLAGS) -fopenmp -o bin/$@_bio main.cpp -DVF3BIO -DVF3P $(LDFLAGSOMP)
clean:
	rm bin/*