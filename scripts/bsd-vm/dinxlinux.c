/* Linux ABI -> FreeBSD translation layer for the Aqueous port.
 *
 * Zig's std.os.linux issues raw Linux syscalls; on FreeBSD those numbers are
 * outside the syscall table and the kernel raises SIGSYS. Aqueous calls them
 * directly in IpcServer.zig, wm/output/Service.zig, GpuPin.zig and others.
 *
 * These wrappers accept Linux ABI constants (flags, errno numbers, sockaddr
 * layout) and translate to FreeBSD. Return convention matches std.os.linux:
 * a non-negative result on success, or -<linux errno> on failure, so the
 * caller's `linux.errno(rc)` switch keeps working unchanged.
 */
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/stat.h>
#include <sys/resource.h>
#include <sys/time.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <stddef.h>
#include <stdint.h>

/* ---- Linux errno numbers (stable ABI) ---- */
enum {
	L_EPERM = 1, L_ENOENT = 2, L_EINTR = 4, L_EIO = 5, L_EBADF = 9,
	L_EAGAIN = 11, L_ENOMEM = 12, L_EACCES = 13, L_EFAULT = 14,
	L_EBUSY = 16, L_EEXIST = 17, L_ENODEV = 19, L_ENOTDIR = 20,
	L_EISDIR = 21, L_EINVAL = 22, L_ENFILE = 23, L_EMFILE = 24,
	L_ENOSPC = 28, L_EROFS = 30, L_EPIPE = 32, L_ENAMETOOLONG = 36,
	L_ENOSYS = 38, L_ELOOP = 40, L_ENOTSOCK = 88, L_EOPNOTSUPP = 95,
	L_EAFNOSUPPORT = 97, L_EADDRINUSE = 98, L_EADDRNOTAVAIL = 99,
	L_ENETDOWN = 100, L_ENETUNREACH = 101, L_ECONNRESET = 104,
	L_ENOBUFS = 105, L_EISCONN = 106, L_ENOTCONN = 107,
	L_ETIMEDOUT = 110, L_ECONNREFUSED = 111, L_EHOSTUNREACH = 113,
	L_EALREADY = 114, L_EINPROGRESS = 115,
};

static int
lerrno(int e)
{
	switch (e) {
	case EPERM: return L_EPERM;
	case ENOENT: return L_ENOENT;
	case EINTR: return L_EINTR;
	case EIO: return L_EIO;
	case EBADF: return L_EBADF;
	case EAGAIN: return L_EAGAIN;
#if EWOULDBLOCK != EAGAIN
	case EWOULDBLOCK: return L_EAGAIN;
#endif
	case ENOMEM: return L_ENOMEM;
	case EACCES: return L_EACCES;
	case EFAULT: return L_EFAULT;
	case EBUSY: return L_EBUSY;
	case EEXIST: return L_EEXIST;
	case ENODEV: return L_ENODEV;
	case ENOTDIR: return L_ENOTDIR;
	case EISDIR: return L_EISDIR;
	case EINVAL: return L_EINVAL;
	case ENFILE: return L_ENFILE;
	case EMFILE: return L_EMFILE;
	case ENOSPC: return L_ENOSPC;
	case EROFS: return L_EROFS;
	case EPIPE: return L_EPIPE;
	case ENAMETOOLONG: return L_ENAMETOOLONG;
	case ENOSYS: return L_ENOSYS;
	case ELOOP: return L_ELOOP;
	case ENOTSOCK: return L_ENOTSOCK;
	case EOPNOTSUPP: return L_EOPNOTSUPP;
	case EAFNOSUPPORT: return L_EAFNOSUPPORT;
	case EADDRINUSE: return L_EADDRINUSE;
	case EADDRNOTAVAIL: return L_EADDRNOTAVAIL;
	case ENETDOWN: return L_ENETDOWN;
	case ENETUNREACH: return L_ENETUNREACH;
	case ECONNRESET: return L_ECONNRESET;
	case ENOBUFS: return L_ENOBUFS;
	case EISCONN: return L_EISCONN;
	case ENOTCONN: return L_ENOTCONN;
	case ETIMEDOUT: return L_ETIMEDOUT;
	case ECONNREFUSED: return L_ECONNREFUSED;
	case EHOSTUNREACH: return L_EHOSTUNREACH;
	case EALREADY: return L_EALREADY;
	case EINPROGRESS: return L_EINPROGRESS;
	default: return L_EINVAL;
	}
}

#define L_FAIL() (-(int64_t)lerrno(errno))

/* ---- Linux flag bits ---- */
#define L_O_CREAT	 00000100
#define L_O_EXCL	 00000200
#define L_O_NOCTTY	 00000400
#define L_O_TRUNC	 0001000
#define L_O_APPEND	 0002000
#define L_O_NONBLOCK	 0004000
#define L_O_DIRECTORY	 00200000
#define L_O_NOFOLLOW	 00400000
#define L_O_CLOEXEC	 02000000

#define L_SOCK_NONBLOCK	 00004000
#define L_SOCK_CLOEXEC	 02000000

#define L_MSG_PEEK	 0x2
#define L_MSG_DONTWAIT	 0x40
#define L_MSG_NOSIGNAL	 0x4000

#define L_SOL_SOCKET	 1
#define L_SO_PEERCRED	 17

/* Linux AF_* that differ from FreeBSD, or have no FreeBSD equivalent.
 * AF_UNIX(1)/AF_INET(2) are identical on both and need no translation. */
#define L_AF_INET6	10	/* FreeBSD AF_INET6 is 28 */
#define L_AF_NETLINK	16	/* no FreeBSD equivalent (udev uevent) */

#define L_AT_SYMLINK_NOFOLLOW	0x100
#define L_AT_EMPTY_PATH		0x1000

#define L_RLIMIT_NPROC	 6
#define L_RLIMIT_NOFILE	 7

static int
xlat_open(int f)
{
	int o = f & O_ACCMODE;

	if (f & L_O_CREAT) o |= O_CREAT;
	if (f & L_O_EXCL) o |= O_EXCL;
	if (f & L_O_NOCTTY) o |= O_NOCTTY;
	if (f & L_O_TRUNC) o |= O_TRUNC;
	if (f & L_O_APPEND) o |= O_APPEND;
	if (f & L_O_NONBLOCK) o |= O_NONBLOCK;
	if (f & L_O_DIRECTORY) o |= O_DIRECTORY;
	if (f & L_O_NOFOLLOW) o |= O_NOFOLLOW;
	if (f & L_O_CLOEXEC) o |= O_CLOEXEC;
	return o;
}

static int
xlat_fcntl_arg(int cmd, int arg)
{
	if (cmd == F_SETFL || cmd == F_GETFL) {
		int o = 0;
		if (arg & L_O_NONBLOCK) o |= O_NONBLOCK;
		if (arg & L_O_APPEND) o |= O_APPEND;
		return o;
	}
	return arg;
}

static int
xlat_msg(int f)
{
	int o = 0;

	if (f & L_MSG_PEEK) o |= MSG_PEEK;
	if (f & L_MSG_DONTWAIT) o |= MSG_DONTWAIT;
#ifdef MSG_NOSIGNAL
	if (f & L_MSG_NOSIGNAL) o |= MSG_NOSIGNAL;
#endif
	return o;
}

/* Linux sockaddr_un: sun_family (u16) + sun_path[108].
 * FreeBSD sockaddr_un: sun_len (u8) + sun_family (u8) + sun_path[104]. */
struct l_sockaddr_un {
	uint16_t family;
	char path[108];
};

static socklen_t
to_bsd_un(const void *addr, socklen_t addrlen, struct sockaddr_un *out)
{
	const struct l_sockaddr_un *l = addr;
	size_t n;

	memset(out, 0, sizeof(*out));
	if (addrlen < offsetof(struct l_sockaddr_un, path))
		return 0;
	/* Call sites build linux.sockaddr.un without always setting sun_family;
	 * accept AF_UNIX (1) or unset (0). These paths only carry UNIX sockets. */
	if (l->family != 0 && l->family != AF_UNIX)
		return 0;
	for (n = 0; n < sizeof(l->path) && l->path[n] != '\0'; n++)
		;
	if (n > sizeof(out->sun_path))
		n = sizeof(out->sun_path);
	memcpy(out->sun_path, l->path, n);
	out->sun_family = AF_UNIX;
	out->sun_len = (uint8_t)(offsetof(struct sockaddr_un, sun_path) + n + 1);
	return out->sun_len;
}

/* ---- wrappers ---- */

/* Translate a Linux AF_* domain to the FreeBSD value. AF_UNIX/AF_INET match.
 * Returns -1 for domains FreeBSD cannot service (NETLINK); callers that check
 * errno(rc) treat it as a soft failure and skip the feature. */
static int
xlat_domain(int d)
{
	switch (d) {
	case AF_UNIX:	return AF_UNIX;
	case AF_INET:	return AF_INET;
	case L_AF_INET6:	return AF_INET6;
	case L_AF_NETLINK:	return -1;	/* udev uevent: Linux-only */
	default:	return d;
	}
}

int64_t
dinx_socket(int domain, int type, int protocol)
{
	int dom = xlat_domain(domain);
	int base = type & 0xF;
	int fd;

	if (dom < 0)
		return -(int64_t)L_EAFNOSUPPORT;
	fd = socket(dom, base, protocol);
	if (fd < 0)
		return L_FAIL();
	if (type & L_SOCK_NONBLOCK) {
		int fl = fcntl(fd, F_GETFL, 0);
		fcntl(fd, F_SETFL, fl | O_NONBLOCK);
	}
	if (type & L_SOCK_CLOEXEC)
		fcntl(fd, F_SETFD, FD_CLOEXEC);
	return fd;
}

int64_t
dinx_accept4(int fd, void *addr, socklen_t *addrlen, int flags)
{
	int nfd = accept(fd, addr, addrlen);
	if (nfd < 0)
		return L_FAIL();
	if (flags & L_SOCK_NONBLOCK) {
		int fl = fcntl(nfd, F_GETFL, 0);
		fcntl(nfd, F_SETFL, fl | O_NONBLOCK);
	}
	if (flags & L_SOCK_CLOEXEC)
		fcntl(nfd, F_SETFD, FD_CLOEXEC);
	return nfd;
}

int64_t
dinx_bind(int fd, const void *addr, socklen_t addrlen)
{
	struct sockaddr_un un;
	socklen_t len = to_bsd_un(addr, addrlen, &un);

	if (len == 0)
		return -(int64_t)L_EINVAL;
	return bind(fd, (struct sockaddr *)&un, len) == 0 ? 0 : L_FAIL();
}

int64_t
dinx_connect(int fd, const void *addr, socklen_t addrlen)
{
	struct sockaddr_un un;
	socklen_t len = to_bsd_un(addr, addrlen, &un);

	if (len == 0)
		return -(int64_t)L_EINVAL;
	return connect(fd, (struct sockaddr *)&un, len) == 0 ? 0 : L_FAIL();
}

int64_t
dinx_listen(int fd, int backlog)
{
	return listen(fd, backlog) == 0 ? 0 : L_FAIL();
}

int64_t
dinx_close(int fd)
{
	return close(fd) == 0 ? 0 : L_FAIL();
}

int64_t
dinx_unlink(const char *path)
{
	return unlink(path) == 0 ? 0 : L_FAIL();
}

int64_t
dinx_chmod(const char *path, unsigned mode)
{
	return chmod(path, (mode_t)mode) == 0 ? 0 : L_FAIL();
}

int64_t
dinx_mkdir(const char *path, unsigned mode)
{
	return mkdir(path, (mode_t)mode) == 0 ? 0 : L_FAIL();
}

int64_t
dinx_rmdir(const char *path)
{
	return rmdir(path) == 0 ? 0 : L_FAIL();
}

int64_t
dinx_open(const char *path, unsigned flags, unsigned mode)
{
	int fd = open(path, xlat_open((int)flags), (mode_t)mode);
	return fd < 0 ? L_FAIL() : fd;
}

int64_t
dinx_read(int fd, void *buf, size_t n)
{
	ssize_t r = read(fd, buf, n);
	return r < 0 ? L_FAIL() : (int64_t)r;
}

int64_t
dinx_readlink(const char *path, char *buf, size_t n)
{
	ssize_t r = readlink(path, buf, n);
	return r < 0 ? L_FAIL() : (int64_t)r;
}

int64_t
dinx_fsync(int fd)
{
	return fsync(fd) == 0 ? 0 : L_FAIL();
}

int64_t
dinx_pause(void)
{
	pause();
	return L_FAIL();
}

int64_t
dinx_recvfrom(int fd, void *buf, size_t n, int flags, void *addr, socklen_t *addrlen)
{
	ssize_t r = recvfrom(fd, buf, n, xlat_msg(flags), addr, addrlen);
	return r < 0 ? L_FAIL() : (int64_t)r;
}

int64_t
dinx_sendto(int fd, const void *buf, size_t n, int flags, const void *addr, socklen_t addrlen)
{
	ssize_t r = sendto(fd, buf, n, xlat_msg(flags), addr, addrlen);
	return r < 0 ? L_FAIL() : (int64_t)r;
}

int64_t
dinx_fcntl(int fd, int cmd, int64_t arg)
{
	int r = fcntl(fd, cmd, xlat_fcntl_arg(cmd, (int)arg));
	return r < 0 ? L_FAIL() : r;
}

int64_t
dinx_getrlimit(int resource, void *rlim)
{
	int r = resource;

	if (resource == L_RLIMIT_NOFILE) r = RLIMIT_NOFILE;
	else if (resource == L_RLIMIT_NPROC) r = RLIMIT_NPROC;
	return getrlimit(r, (struct rlimit *)rlim) == 0 ? 0 : L_FAIL();
}

/* SO_PEERCRED is Linux-only; translate to FreeBSD getpeereid().
 * Caller's buffer is the Linux struct ucred { pid_t; uid_t; gid_t; }. */
int64_t
dinx_getsockopt(int fd, int level, int optname, void *optval, socklen_t *optlen)
{
	if (level == L_SOL_SOCKET && optname == L_SO_PEERCRED) {
		uid_t euid;
		gid_t egid;
		int32_t *cred = optval;

		if (getpeereid(fd, &euid, &egid) != 0)
			return L_FAIL();
		cred[0] = 0; /* pid is unavailable on FreeBSD */
		cred[1] = (int32_t)euid;
		cred[2] = (int32_t)egid;
		if (optlen)
			*optlen = 12;
		return 0;
	}
	if (level == L_SOL_SOCKET)
		level = SOL_SOCKET;
	return getsockopt(fd, level, optname, optval, optlen) == 0 ? 0 : L_FAIL();
}

/* Linux struct statx layout (prefix); filled from fstatat(2). */
struct dinx_statx_ts {
	int64_t sec;
	uint32_t nsec;
	int32_t reserved;
};

struct dinx_statx {
	uint32_t mask;
	uint32_t blksize;
	uint64_t attributes;
	uint32_t nlink;
	uint32_t uid;
	uint32_t gid;
	uint16_t mode;
	uint16_t spare0[1];
	uint64_t ino;
	uint64_t size;
	uint64_t blocks;
	uint64_t attributes_mask;
	struct dinx_statx_ts atime;
	struct dinx_statx_ts btime;
	struct dinx_statx_ts ctime;
	struct dinx_statx_ts mtime;
};

#define L_STATX_TYPE	 0x1
#define L_STATX_MODE	 0x2
#define L_STATX_NLINK	 0x4
#define L_STATX_UID	 0x8
#define L_STATX_GID	 0x10
#define L_STATX_ATIME	 0x20
#define L_STATX_MTIME	 0x40
#define L_STATX_CTIME	 0x80
#define L_STATX_INO	 0x100
#define L_STATX_SIZE	 0x200
#define L_STATX_BLOCKS	 0x400
#define L_STATX_BASIC	 0x7ff

int64_t
dinx_statx(int dirfd, const char *path, unsigned flags, unsigned mask, void *buf)
{
	struct stat st;
	struct dinx_statx *sx = buf;
	int bflags = 0;
	int rc;

	if (sx == NULL)
		return -(int64_t)L_EFAULT;
	memset(sx, 0, sizeof(*sx));
	if (flags & L_AT_SYMLINK_NOFOLLOW)
		bflags |= AT_SYMLINK_NOFOLLOW;
	if (path != NULL && path[0] == '\0' && (flags & L_AT_EMPTY_PATH))
		rc = fstat(dirfd, &st);
	else
		rc = fstatat(dirfd, path, &st, bflags);
	if (rc != 0)
		return L_FAIL();

	sx->mask = L_STATX_BASIC;
	sx->blksize = (uint32_t)st.st_blksize;
	sx->nlink = (uint32_t)st.st_nlink;
	sx->uid = (uint32_t)st.st_uid;
	sx->gid = (uint32_t)st.st_gid;
	sx->mode = (uint16_t)st.st_mode;
	sx->ino = (uint64_t)st.st_ino;
	sx->size = (uint64_t)st.st_size;
	sx->blocks = (uint64_t)st.st_blocks;
	sx->atime.sec = st.st_atim.tv_sec;
	sx->atime.nsec = (uint32_t)st.st_atim.tv_nsec;
	sx->ctime.sec = st.st_ctim.tv_sec;
	sx->ctime.nsec = (uint32_t)st.st_ctim.tv_nsec;
	sx->mtime.sec = st.st_mtim.tv_sec;
	sx->mtime.nsec = (uint32_t)st.st_mtim.tv_nsec;
	(void)mask;
	return 0;
}
