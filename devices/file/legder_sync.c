#include <errno.h>
#include <fcntl.h>

#ifdef _WIN32
#include <io.h>
#include <sys/stat.h>
#else
#include <unistd.h>
#endif

int legder_sync_file(const char *path)
{
#ifdef _WIN32
    int fd = _open(path, _O_WRONLY | _O_BINARY);
    if (fd < 0) {
        return -1;
    }

    int sync_result = _commit(fd);
    int close_result = _close(fd);
#else
    int fd = open(path, O_WRONLY);
    if (fd < 0) {
        return -1;
    }

    int sync_result;
    do {
        sync_result = fsync(fd);
    } while (sync_result < 0 && errno == EINTR);
    int close_result = close(fd);
#endif

    return (sync_result == 0 && close_result == 0) ? 0 : -1;
}
