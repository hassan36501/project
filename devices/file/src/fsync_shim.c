#ifdef _WIN32
#include <io.h>
int legder_fsync(int fd) {
    return _commit(fd);
}
#else
#include <unistd.h>
int legder_fsync(int fd) {
    return fsync(fd);
}
#endif
