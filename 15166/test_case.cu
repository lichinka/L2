template <typename T>
struct A {
    T* p;
    int *b;
    A(int a) {
        p = new T[a];
        b = new int[a];
    }
};


int main() {
    A<int> x(10);

    return 0;
}
