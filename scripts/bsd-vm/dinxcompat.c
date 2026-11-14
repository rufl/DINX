/* FreeBSD compat shim for Linux-only libc symbols used by Pearl.
 * statx(2) emulated over fstatat(2); mallopt(3) is a glibc tuning no-op.
 * The struct layout matches the Linux kernel struct statx prefix that Zig's
 * std.os.linux.Statx describes; trailing kernel fields are left zero.
 */
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <string.h>
#include <stdint.h>

struct dinx_statx_timestamp {
    int64_t tv_sec;
    uint32_t tv_nsec;
    int32_t __reserved;
};

struct dinx_statx {
    uint32_t stx_mask;
    uint32_t stx_blksize;
    uint64_t stx_attributes;
    uint32_t stx_nlink;
    uint32_t stx_uid;
    uint32_t stx_gid;
    uint16_t stx_mode;
    uint16_t __spare0[1];
    uint64_t stx_ino;
    uint64_t stx_size;
    uint64_t stx_blocks;
    uint64_t stx_attributes_mask;
    struct dinx_statx_timestamp stx_atime;
    struct dinx_statx_timestamp stx_btime;
    struct dinx_statx_timestamp stx_ctime;
    struct dinx_statx_timestamp stx_mtime;
    uint32_t stx_rdev_major;
    uint32_t stx_rdev_minor;
    uint32_t stx_dev_major;
    uint32_t stx_dev_minor;
    uint64_t stx_mnt_id;
    uint32_t stx_dio_mem_align;
    uint32_t stx_dio_offset_align;
};

#define DINX_STATX_TYPE 0x00000001U
#define DINX_STATX_MODE 0x00000002U
#define DINX_STATX_NLINK 0x00000004U
#define DINX_STATX_UID 0x00000008U
#define DINX_STATX_GID 0x00000010U
#define DINX_STATX_ATIME 0x00000020U
#define DINX_STATX_MTIME 0x00000040U
#define DINX_STATX_CTIME 0x00000080U
#define DINX_STATX_INO 0x00000100U
#define DINX_STATX_SIZE 0x00000200U
#define DINX_STATX_BLOCKS 0x00000400U
#define DINX_STATX_BASIC_STATS 0x000007ffU

static void dinx_ts(struct dinx_statx_timestamp *t, struct timespec ts) {
    t->tv_sec = ts.tv_sec;
    t->tv_nsec = ts.tv_nsec;
    t->__reserved = 0;
}

int statx(int dirfd, const char *path, int flags, unsigned int mask,
          struct dinx_statx *buf) {
    struct stat st;
    int rc;
    if (!buf)
        return -1;
    memset(buf, 0, sizeof(*buf));
    if (path && path[0] == '\0' && (flags & AT_EMPTY_PATH))
        rc = fstat(dirfd, &st);
    else
        rc = fstatat(dirfd, path, &st, flags & (AT_SYMLINK_NOFOLLOW | AT_EMPTY_PATH));
    if (rc != 0)
        return -1;
    buf->stx_mask = DINX_STATX_BASIC_STATS;
    buf->stx_blksize = st.st_blksize;
    buf->stx_nlink = st.st_nlink;
    buf->stx_uid = st.st_uid;
    buf->stx_gid = st.st_gid;
    buf->stx_mode = st.st_mode;
    buf->stx_ino = st.st_ino;
    buf->stx_size = st.st_size;
    buf->stx_blocks = st.st_blocks;
    dinx_ts(&buf->stx_atime, st.st_atim);
    dinx_ts(&buf->stx_ctime, st.st_ctim);
    dinx_ts(&buf->stx_mtime, st.st_mtim);
    buf->stx_rdev_major = major(st.st_rdev);
    buf->stx_rdev_minor = minor(st.st_rdev);
    buf->stx_dev_major = major(st.st_dev);
    buf->stx_dev_minor = minor(st.st_dev);
    (void)mask;
    return 0;
}

int mallopt(int cmd, int value) {
    (void)cmd;
    (void)value;
    return 1;
}

/* systemd sd_pidfd_get_user_unit: no FreeBSD equivalent (no user units).
 * Degrade gracefully: callers fall back to non-unit session tracking. */
#include <errno.h>
int sd_pidfd_get_user_unit(int pidfd, char **unit) {
    (void)pidfd;
    if (unit)
        *unit = 0;
    return -ENXIO;
}

/* glibc __errno_location -> FreeBSD __error(). */
int *__errno_location(void) {
    return __error();
}

/* FreeBSD crt1.o normally defines __progname; Zig's startup does not.
 * libc references it (err/warn/getopt paths). Cosmetic fallback name. */
char *__progname = "dinx";

/* FreeBSD libc expects the executable to provide `environ`; Zig helper exes
 * (aqueousctl) do not export it. Provide the storage here; libc's startup
 * fills it through the interposed symbol. */
char **environ;
