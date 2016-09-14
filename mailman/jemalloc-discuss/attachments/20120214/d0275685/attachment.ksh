*** jemalloc.tmp/include/jemalloc/internal/atomic.h	Thu Jan  1 00:00:00 1970
--- jemalloc/include/jemalloc/internal/atomic.h	Thu Jan  1 00:00:00 1970
***************
*** 133,138 ****
--- 133,151 ----
  
  	return (OSAtomicAdd32(-((int32_t)x), (int32_t *)p));
  }
+ #elif defined(_WIN32)
+ #pragma intrinsic(_InterlockedExchangeAdd)
+ JEMALLOC_INLINE uint32_t
+ atomic_add_uint32(uint32_t *p, uint32_t x)
+ {
+     return _InterlockedExchangeAdd(p, x);
+ }
+ 
+ JEMALLOC_INLINE uint32_t
+ atomic_sub_uint32(uint32_t *p, uint32_t x)
+ {
+     return _InterlockedExchangeAdd(p, -x);
+ }
  #elif (defined(__i386__) || defined(__amd64_) || defined(__x86_64__))
  JEMALLOC_INLINE uint32_t
  atomic_add_uint32(uint32_t *p, uint32_t x)
*** jemalloc.tmp/include/jemalloc/internal/compat_win32.h	Thu Jan  1 00:00:00 1970
--- jemalloc/include/jemalloc/internal/compat_win32.h	Thu Jan  1 00:00:00 1970
***************
*** 0 ****
--- 1,47 ----
+ #ifndef __JEMALLOC_COMPAT_WIN32_H__
+ #define __JEMALLOC_COMPAT_WIN32_H__
+ #include <windows.h>
+ #pragma warning(disable: 4146 4334)
+ #define _CRT_SPINCOUNT 5000
+ #define	bool BOOL
+ #define	false FALSE
+ #define	true TRUE
+ #define	inline __inline
+ #define pthread_t DWORD
+ #define pthread_key_t DWORD
+ #define pthread_key_create(tsd, func) win32_key_create(tsd, func)
+ #define pthread_setspecific(tsd, v) win32_setspecific(tsd, v)
+ #define pthread_getspecific(tsd) win32_getspecific(tsd)
+ #define	__thread __declspec(thread)
+ #define	pthread_self() GetCurrentThreadId()
+ #define	issetugid() 0
+ 
+ int win32_key_create(pthread_key_t *key, void (*destructor)(void*));
+ int win32_setspecific(pthread_key_t key, const void *value);
+ void *win32_getspecific(pthread_key_t key);
+ 
+ #include <intrin.h>
+ /* use MSVC intrinsics */
+ #pragma intrinsic(_BitScanForward)
+ static __forceinline int
+ ffs(int x)
+ {
+ 	unsigned long i;
+ 
+ 	if (_BitScanForward(&i, x) != 0)
+ 		return (i + 1);
+ 
+ 	return (0);
+ }
+ 
+ static __forceinline int
+ ffsl(long x)
+ {
+ 	unsigned long i;
+ 
+ 	if (_BitScanForward(&i, x) != 0)
+ 		return (i + 1);
+ 
+ 	return (0);
+ }
+ #endif
*** jemalloc.tmp/include/jemalloc/internal/ctl.h	Thu Jan  1 00:00:00 1970
--- jemalloc/include/jemalloc/internal/ctl.h	Thu Jan  1 00:00:00 1970
***************
*** 11,17 ****
  
  struct ctl_node_s {
  	bool			named;
! 	union {
  		struct {
  			const char	*name;
  			/* If (nchildren == 0), this is a terminal node. */
--- 11,22 ----
  
  struct ctl_node_s {
  	bool			named;
! #ifdef _MSC_VER
! 	struct
! #else
! 	union
! #endif
! 	{
  		struct {
  			const char	*name;
  			/* If (nchildren == 0), this is a terminal node. */
***************
*** 86,92 ****
  		malloc_write("<jemalloc>: Failure in xmallctl(\"");	\
  		malloc_write(name);					\
  		malloc_write("\", ...)\n");				\
! 		abort();						\
  	}								\
  } while (0)
  
--- 91,97 ----
  		malloc_write("<jemalloc>: Failure in xmallctl(\"");	\
  		malloc_write(name);					\
  		malloc_write("\", ...)\n");				\
! 		xabort();						\
  	}								\
  } while (0)
  
***************
*** 96,102 ****
  		    "<jemalloc>: Failure in xmallctlnametomib(\"");	\
  		malloc_write(name);					\
  		malloc_write("\", ...)\n");				\
! 		abort();						\
  	}								\
  } while (0)
  
--- 101,107 ----
  		    "<jemalloc>: Failure in xmallctlnametomib(\"");	\
  		malloc_write(name);					\
  		malloc_write("\", ...)\n");				\
! 		xabort();						\
  	}								\
  } while (0)
  
***************
*** 105,111 ****
  	    newlen) != 0) {						\
  		malloc_write(						\
  		    "<jemalloc>: Failure in xmallctlbymib()\n");	\
! 		abort();						\
  	}								\
  } while (0)
  
--- 110,116 ----
  	    newlen) != 0) {						\
  		malloc_write(						\
  		    "<jemalloc>: Failure in xmallctlbymib()\n");	\
! 		xabort();						\
  	}								\
  } while (0)
  
*** jemalloc.tmp/include/jemalloc/internal/jemalloc_internal.h	Thu Jan  1 00:00:00 1970
--- jemalloc/include/jemalloc/internal/jemalloc_internal.h	Thu Jan  1 00:00:00 1970
***************
*** 0 ****
--- 1,797 ----
+ #include <config.h>
+ #include "jemalloc/jemalloc_defs.h"
+ #ifdef _MSC_VER
+ #include "jemalloc/internal/compat_win32.h"
+ #else
+ #include <sys/mman.h>
+ #include <sys/sysctl.h>
+ #include <pthread.h>
+ #include <sched.h>
+ #include <stdbool.h>
+ #include <inttypes.h>
+ #endif
+ #include <sys/param.h>
+ #include <sys/time.h>
+ #include <sys/types.h>
+ #include <sys/uio.h>
+ 
+ #include <errno.h>
+ #include <limits.h>
+ #ifndef SIZE_T_MAX
+ #  define SIZE_T_MAX	SIZE_MAX
+ #endif
+ #include <stdarg.h>
+ #include <stdio.h>
+ #include <stdlib.h>
+ #include <stdint.h>
+ #include <stddef.h>
+ #ifndef offsetof
+ #  define offsetof(type, member)	((size_t)&(((type *)NULL)->member))
+ #endif
+ #include <string.h>
+ #include <strings.h>
+ #include <ctype.h>
+ #include <unistd.h>
+ #include <fcntl.h>
+ #include <math.h>
+ 
+ #define	JEMALLOC_MANGLE
+ #include "../jemalloc.h"
+ 
+ #include "jemalloc/internal/private_namespace.h"
+ 
+ #if (defined(JEMALLOC_OSATOMIC) || defined(JEMALLOC_OSSPIN))
+ #include <libkern/OSAtomic.h>
+ #endif
+ 
+ #ifdef JEMALLOC_ZONE
+ #include <mach/mach_error.h>
+ #include <mach/mach_init.h>
+ #include <mach/vm_map.h>
+ #include <malloc/malloc.h>
+ #endif
+ 
+ #ifdef JEMALLOC_LAZY_LOCK
+ #include <dlfcn.h>
+ #endif
+ 
+ #define	RB_COMPACT
+ #include "jemalloc/internal/rb.h"
+ #include "jemalloc/internal/qr.h"
+ #include "jemalloc/internal/ql.h"
+ 
+ extern void	(*JEMALLOC_P(malloc_message))(void *wcbopaque, const char *s);
+ 
+ /*
+  * Define a custom assert() in order to reduce the chances of deadlock during
+  * assertion failure.
+  */
+ #define JEMALLOC_DEBUG
+ #ifndef assert
+ #  ifdef JEMALLOC_DEBUG
+ #    define assert(e) do {						\
+ 	if (!(e)) {							\
+ 		char line_buf[UMAX2S_BUFSIZE];				\
+ 		malloc_write("<jemalloc>: ");				\
+ 		malloc_write(__FILE__);					\
+ 		malloc_write(":");					\
+ 		malloc_write(u2s(__LINE__, 10, line_buf));		\
+ 		malloc_write(": Failed assertion: ");			\
+ 		malloc_write("\"");					\
+ 		malloc_write(#e);					\
+ 		malloc_write("\"\n");					\
+ 		xabort();						\
+ 	}								\
+ } while (0)
+ #  else
+ #    define assert(e)
+ #  endif
+ #endif
+ 
+ #ifdef JEMALLOC_DEBUG
+ #  define dassert(e) assert(e)
+ #else
+ #  define dassert(e)
+ #endif
+ 
+ /*
+  * jemalloc can conceptually be broken into components (arena, tcache, etc.),
+  * but there are circular dependencies that cannot be broken without
+  * substantial performance degradation.  In order to reduce the effect on
+  * visual code flow, read the header files in multiple passes, with one of the
+  * following cpp variables defined during each pass:
+  *
+  *   JEMALLOC_H_TYPES   : Preprocessor-defined constants and psuedo-opaque data
+  *                        types.
+  *   JEMALLOC_H_STRUCTS : Data structures.
+  *   JEMALLOC_H_EXTERNS : Extern data declarations and function prototypes.
+  *   JEMALLOC_H_INLINES : Inline functions.
+  */
+ /******************************************************************************/
+ #define JEMALLOC_H_TYPES
+ 
+ #define	ALLOCM_LG_ALIGN_MASK	((int)0x3f)
+ 
+ #define	ZU(z)	((size_t)z)
+ 
+ #ifndef __DECONST
+ #  define	__DECONST(type, var)	((type)(uintptr_t)(const void *)(var))
+ #endif
+ 
+ #ifdef JEMALLOC_DEBUG
+    /* Disable inlining to make debugging easier. */
+ #  define JEMALLOC_INLINE
+ #ifndef inline
+ #  define inline
+ #endif
+ #else
+ #  define JEMALLOC_ENABLE_INLINE
+ #  define JEMALLOC_INLINE static inline
+ #endif
+ 
+ /* Size of stack-allocated buffer passed to buferror(). */
+ #define	BUFERROR_BUF		64
+ 
+ /* Minimum alignment of allocations is 2^LG_QUANTUM bytes. */
+ #if defined(__i386__) || defined(_MSC_VER)
+ #  define LG_QUANTUM		4
+ #endif
+ #ifdef __ia64__
+ #  define LG_QUANTUM		4
+ #endif
+ #ifdef __alpha__
+ #  define LG_QUANTUM		4
+ #endif
+ #ifdef __sparc64__
+ #  define LG_QUANTUM		4
+ #endif
+ #if (defined(__amd64__) || defined(__x86_64__))
+ #  define LG_QUANTUM		4
+ #endif
+ #ifdef __arm__
+ #  define LG_QUANTUM		3
+ #endif
+ #ifdef __mips__
+ #  define LG_QUANTUM		3
+ #endif
+ #ifdef __powerpc__
+ #  define LG_QUANTUM		4
+ #endif
+ #ifdef __s390x__
+ #  define LG_QUANTUM		4
+ #endif
+ 
+ #define	QUANTUM			((size_t)(1U << LG_QUANTUM))
+ #define	QUANTUM_MASK		(QUANTUM - 1)
+ 
+ /* Return the smallest quantum multiple that is >= a. */
+ #define	QUANTUM_CEILING(a)						\
+ 	(((a) + QUANTUM_MASK) & ~QUANTUM_MASK)
+ 
+ #define	LONG			((size_t)(1U << LG_SIZEOF_LONG))
+ #define	LONG_MASK		(LONG - 1)
+ 
+ /* Return the smallest long multiple that is >= a. */
+ #define	LONG_CEILING(a)						\
+ 	(((a) + LONG_MASK) & ~LONG_MASK)
+ 
+ #define	SIZEOF_PTR		(1U << LG_SIZEOF_PTR)
+ #define	PTR_MASK		(SIZEOF_PTR - 1)
+ 
+ /* Return the smallest (void *) multiple that is >= a. */
+ #define	PTR_CEILING(a)						\
+ 	(((a) + PTR_MASK) & ~PTR_MASK)
+ 
+ /*
+  * Maximum size of L1 cache line.  This is used to avoid cache line aliasing.
+  * In addition, this controls the spacing of cacheline-spaced size classes.
+  */
+ #define	LG_CACHELINE		6
+ #define	CACHELINE		((size_t)(1U << LG_CACHELINE))
+ #define	CACHELINE_MASK		(CACHELINE - 1)
+ 
+ /* Return the smallest cacheline multiple that is >= s. */
+ #define	CACHELINE_CEILING(s)						\
+ 	(((s) + CACHELINE_MASK) & ~CACHELINE_MASK)
+ 
+ /*
+  * Page size.  STATIC_PAGE_SHIFT is determined by the configure script.  If
+  * DYNAMIC_PAGE_SHIFT is enabled, only use the STATIC_PAGE_* macros where
+  * compile-time values are required for the purposes of defining data
+  * structures.
+  */
+ #define	STATIC_PAGE_SIZE ((size_t)(1U << STATIC_PAGE_SHIFT))
+ #define	STATIC_PAGE_MASK ((size_t)(STATIC_PAGE_SIZE - 1))
+ 
+ #ifdef PAGE_SHIFT
+ #  undef PAGE_SHIFT
+ #endif
+ #ifdef PAGE_SIZE
+ #  undef PAGE_SIZE
+ #endif
+ #ifdef PAGE_MASK
+ #  undef PAGE_MASK
+ #endif
+ 
+ #ifdef DYNAMIC_PAGE_SHIFT
+ #  define PAGE_SHIFT	lg_pagesize
+ #  define PAGE_SIZE	pagesize
+ #  define PAGE_MASK	pagesize_mask
+ #else
+ #  define PAGE_SHIFT	STATIC_PAGE_SHIFT
+ #  define PAGE_SIZE	STATIC_PAGE_SIZE
+ #  define PAGE_MASK	STATIC_PAGE_MASK
+ #endif
+ 
+ /* Return the smallest pagesize multiple that is >= s. */
+ #define	PAGE_CEILING(s)							\
+ 	(((s) + PAGE_MASK) & ~PAGE_MASK)
+ 
+ #include "jemalloc/internal/atomic.h"
+ #include "jemalloc/internal/prn_.h"
+ #include "jemalloc/internal/ckh.h"
+ #include "jemalloc/internal/stats.h"
+ #include "jemalloc/internal/ctl.h"
+ #include "jemalloc/internal/mutex.h"
+ #include "jemalloc/internal/mb.h"
+ #include "jemalloc/internal/extent.h"
+ #include "jemalloc/internal/arena.h"
+ #include "jemalloc/internal/bitmap.h"
+ #include "jemalloc/internal/base.h"
+ #include "jemalloc/internal/chunk.h"
+ #include "jemalloc/internal/huge.h"
+ #include "jemalloc/internal/rtree.h"
+ #include "jemalloc/internal/tcache.h"
+ #include "jemalloc/internal/hash.h"
+ #ifdef JEMALLOC_ZONE
+ #include "jemalloc/internal/zone.h"
+ #endif
+ #include "jemalloc/internal/prof.h"
+ 
+ #undef JEMALLOC_H_TYPES
+ /******************************************************************************/
+ #define JEMALLOC_H_STRUCTS
+ 
+ #include "jemalloc/internal/atomic.h"
+ #include "jemalloc/internal/prn_.h"
+ #include "jemalloc/internal/ckh.h"
+ #include "jemalloc/internal/stats.h"
+ #include "jemalloc/internal/ctl.h"
+ #include "jemalloc/internal/mutex.h"
+ #include "jemalloc/internal/mb.h"
+ #include "jemalloc/internal/bitmap.h"
+ #include "jemalloc/internal/extent.h"
+ #include "jemalloc/internal/arena.h"
+ #include "jemalloc/internal/base.h"
+ #include "jemalloc/internal/chunk.h"
+ #include "jemalloc/internal/huge.h"
+ #include "jemalloc/internal/rtree.h"
+ #include "jemalloc/internal/tcache.h"
+ #include "jemalloc/internal/hash.h"
+ #ifdef JEMALLOC_ZONE
+ #include "jemalloc/internal/zone.h"
+ #endif
+ #include "jemalloc/internal/prof.h"
+ 
+ #ifdef JEMALLOC_STATS
+ typedef struct {
+ 	uint64_t	allocated;
+ 	uint64_t	deallocated;
+ } thread_allocated_t;
+ #endif
+ 
+ #undef JEMALLOC_H_STRUCTS
+ /******************************************************************************/
+ #define JEMALLOC_H_EXTERNS
+ 
+ extern malloc_abort_cb_t malloc_abort_cb;
+ extern bool	opt_abort;
+ #ifdef JEMALLOC_FILL
+ extern bool	opt_junk;
+ #endif
+ #ifdef JEMALLOC_SYSV
+ extern bool	opt_sysv;
+ #endif
+ #ifdef JEMALLOC_XMALLOC
+ extern bool	opt_xmalloc;
+ #endif
+ #ifdef JEMALLOC_FILL
+ extern bool	opt_zero;
+ #endif
+ extern size_t	opt_narenas;
+ 
+ #ifdef DYNAMIC_PAGE_SHIFT
+ extern size_t		pagesize;
+ extern size_t		pagesize_mask;
+ extern size_t		lg_pagesize;
+ #endif
+ 
+ /* Number of CPUs. */
+ extern unsigned		ncpus;
+ 
+ extern malloc_mutex_t	arenas_lock; /* Protects arenas initialization. */
+ extern pthread_key_t	arenas_tsd;
+ #ifndef NO_TLS
+ /*
+  * Map of pthread_self() --> arenas[???], used for selecting an arena to use
+  * for allocations.
+  */
+ extern __thread arena_t	*arenas_tls JEMALLOC_ATTR(tls_model("initial-exec"));
+ #  define ARENA_GET()	arenas_tls
+ #  define ARENA_SET(v)	do {						\
+ 	arenas_tls = (v);						\
+ 	pthread_setspecific(arenas_tsd, (void *)(v));			\
+ } while (0)
+ #else
+ #  define ARENA_GET()	((arena_t *)pthread_getspecific(arenas_tsd))
+ #  define ARENA_SET(v)	do {						\
+ 	pthread_setspecific(arenas_tsd, (void *)(v));			\
+ } while (0)
+ #endif
+ 
+ /*
+  * Arenas that are used to service external requests.  Not all elements of the
+  * arenas array are necessarily used; arenas are created lazily as needed.
+  */
+ extern arena_t		**arenas;
+ extern unsigned		narenas;
+ 
+ #ifdef JEMALLOC_STATS
+ #  ifndef NO_TLS
+ extern __thread thread_allocated_t	thread_allocated_tls;
+ #    define ALLOCATED_GET() (thread_allocated_tls.allocated)
+ #    define ALLOCATEDP_GET() (&thread_allocated_tls.allocated)
+ #    define DEALLOCATED_GET() (thread_allocated_tls.deallocated)
+ #    define DEALLOCATEDP_GET() (&thread_allocated_tls.deallocated)
+ #    define ALLOCATED_ADD(a, d) do {					\
+ 	thread_allocated_tls.allocated += a;				\
+ 	thread_allocated_tls.deallocated += d;				\
+ } while (0)
+ #  else
+ extern pthread_key_t	thread_allocated_tsd;
+ thread_allocated_t	*thread_allocated_get_hard(void);
+ 
+ #    define ALLOCATED_GET() (thread_allocated_get()->allocated)
+ #    define ALLOCATEDP_GET() (&thread_allocated_get()->allocated)
+ #    define DEALLOCATED_GET() (thread_allocated_get()->deallocated)
+ #    define DEALLOCATEDP_GET() (&thread_allocated_get()->deallocated)
+ #    define ALLOCATED_ADD(a, d) do {					\
+ 	thread_allocated_t *thread_allocated = thread_allocated_get();	\
+ 	thread_allocated->allocated += (a);				\
+ 	thread_allocated->deallocated += (d);				\
+ } while (0)
+ #  endif
+ #endif
+ 
+ arena_t	*arenas_extend(unsigned ind);
+ arena_t	*choose_arena_hard(void);
+ int	buferror(int errnum, char *buf, size_t buflen);
+ void	jemalloc_prefork(void);
+ void	jemalloc_postfork(void);
+ 
+ #include "jemalloc/internal/atomic.h"
+ #include "jemalloc/internal/prn_.h"
+ #include "jemalloc/internal/ckh.h"
+ #include "jemalloc/internal/stats.h"
+ #include "jemalloc/internal/ctl.h"
+ #include "jemalloc/internal/mutex.h"
+ #include "jemalloc/internal/mb.h"
+ #include "jemalloc/internal/bitmap.h"
+ #include "jemalloc/internal/extent.h"
+ #include "jemalloc/internal/arena.h"
+ #include "jemalloc/internal/base.h"
+ #include "jemalloc/internal/chunk.h"
+ #include "jemalloc/internal/huge.h"
+ #include "jemalloc/internal/rtree.h"
+ #include "jemalloc/internal/tcache.h"
+ #include "jemalloc/internal/hash.h"
+ #ifdef JEMALLOC_ZONE
+ #include "jemalloc/internal/zone.h"
+ #endif
+ #include "jemalloc/internal/prof.h"
+ 
+ #undef JEMALLOC_H_EXTERNS
+ /******************************************************************************/
+ #define JEMALLOC_H_INLINES
+ 
+ #include "jemalloc/internal/atomic.h"
+ #include "jemalloc/internal/prn_.h"
+ #include "jemalloc/internal/ckh.h"
+ #include "jemalloc/internal/stats.h"
+ #include "jemalloc/internal/ctl.h"
+ #include "jemalloc/internal/mutex.h"
+ #include "jemalloc/internal/mb.h"
+ #include "jemalloc/internal/extent.h"
+ #include "jemalloc/internal/base.h"
+ #include "jemalloc/internal/chunk.h"
+ #include "jemalloc/internal/huge.h"
+ 
+ #ifndef JEMALLOC_ENABLE_INLINE
+ size_t	pow2_ceil(size_t x);
+ size_t	s2u(size_t size);
+ size_t	sa2u(size_t size, size_t alignment, size_t *run_size_p);
+ void	malloc_write(const char *s);
+ arena_t	*choose_arena(void);
+ #  if (defined(JEMALLOC_STATS) && defined(NO_TLS))
+ thread_allocated_t	*thread_allocated_get(void);
+ #  endif
+ #endif
+ 
+ #if (defined(JEMALLOC_ENABLE_INLINE) || defined(JEMALLOC_C_))
+ /* Compute the smallest power of 2 that is >= x. */
+ JEMALLOC_INLINE size_t
+ pow2_ceil(size_t x)
+ {
+ 
+ 	x--;
+ 	x |= x >> 1;
+ 	x |= x >> 2;
+ 	x |= x >> 4;
+ 	x |= x >> 8;
+ 	x |= x >> 16;
+ #if (LG_SIZEOF_PTR == 3)
+ 	x |= x >> 32;
+ #endif
+ 	x++;
+ 	return (x);
+ }
+ 
+ /*
+  * Compute usable size that would result from allocating an object with the
+  * specified size.
+  */
+ JEMALLOC_INLINE size_t
+ s2u(size_t size)
+ {
+ 
+ 	if (size <= small_maxclass)
+ 		return (arena_bin_info[SMALL_SIZE2BIN(size)].reg_size);
+ 	if (size <= arena_maxclass)
+ 		return (PAGE_CEILING(size));
+ 	return (CHUNK_CEILING(size));
+ }
+ 
+ /*
+  * Compute usable size that would result from allocating an object with the
+  * specified size and alignment.
+  */
+ JEMALLOC_INLINE size_t
+ sa2u(size_t size, size_t alignment, size_t *run_size_p)
+ {
+ 	size_t usize;
+ 
+ 	/*
+ 	 * Round size up to the nearest multiple of alignment.
+ 	 *
+ 	 * This done, we can take advantage of the fact that for each small
+ 	 * size class, every object is aligned at the smallest power of two
+ 	 * that is non-zero in the base two representation of the size.  For
+ 	 * example:
+ 	 *
+ 	 *   Size |   Base 2 | Minimum alignment
+ 	 *   -----+----------+------------------
+ 	 *     96 |  1100000 |  32
+ 	 *    144 | 10100000 |  32
+ 	 *    192 | 11000000 |  64
+ 	 *
+ 	 * Depending on runtime settings, it is possible that arena_malloc()
+ 	 * will further round up to a power of two, but that never causes
+ 	 * correctness issues.
+ 	 */
+ 	usize = (size + (alignment - 1)) & (-alignment);
+ 	/*
+ 	 * (usize < size) protects against the combination of maximal
+ 	 * alignment and size greater than maximal alignment.
+ 	 */
+ 	if (usize < size) {
+ 		/* size_t overflow. */
+ 		return (0);
+ 	}
+ 
+ 	if (usize <= arena_maxclass && alignment <= PAGE_SIZE) {
+ 		if (usize <= small_maxclass)
+ 			return (arena_bin_info[SMALL_SIZE2BIN(usize)].reg_size);
+ 		return (PAGE_CEILING(usize));
+ 	} else {
+ 		size_t run_size;
+ 
+ 		/*
+ 		 * We can't achieve subpage alignment, so round up alignment
+ 		 * permanently; it makes later calculations simpler.
+ 		 */
+ 		alignment = PAGE_CEILING(alignment);
+ 		usize = PAGE_CEILING(size);
+ 		/*
+ 		 * (usize < size) protects against very large sizes within
+ 		 * PAGE_SIZE of SIZE_T_MAX.
+ 		 *
+ 		 * (usize + alignment < usize) protects against the
+ 		 * combination of maximal alignment and usize large enough
+ 		 * to cause overflow.  This is similar to the first overflow
+ 		 * check above, but it needs to be repeated due to the new
+ 		 * usize value, which may now be *equal* to maximal
+ 		 * alignment, whereas before we only detected overflow if the
+ 		 * original size was *greater* than maximal alignment.
+ 		 */
+ 		if (usize < size || usize + alignment < usize) {
+ 			/* size_t overflow. */
+ 			return (0);
+ 		}
+ 
+ 		/*
+ 		 * Calculate the size of the over-size run that arena_palloc()
+ 		 * would need to allocate in order to guarantee the alignment.
+ 		 */
+ 		if (usize >= alignment)
+ 			run_size = usize + alignment - PAGE_SIZE;
+ 		else {
+ 			/*
+ 			 * It is possible that (alignment << 1) will cause
+ 			 * overflow, but it doesn't matter because we also
+ 			 * subtract PAGE_SIZE, which in the case of overflow
+ 			 * leaves us with a very large run_size.  That causes
+ 			 * the first conditional below to fail, which means
+ 			 * that the bogus run_size value never gets used for
+ 			 * anything important.
+ 			 */
+ 			run_size = (alignment << 1) - PAGE_SIZE;
+ 		}
+ 		if (run_size_p != NULL)
+ 			*run_size_p = run_size;
+ 
+ 		if (run_size <= arena_maxclass)
+ 			return (PAGE_CEILING(usize));
+ 		return (CHUNK_CEILING(usize));
+ 	}
+ }
+ 
+ /*
+  * Wrapper around malloc_message() that avoids the need for
+  * JEMALLOC_P(malloc_message)(...) throughout the code.
+  */
+ JEMALLOC_INLINE void
+ malloc_write(const char *s)
+ {
+ 
+ 	JEMALLOC_P(malloc_message)(NULL, s);
+ }
+ 
+ /*
+  * Choose an arena based on a per-thread value (fast-path code, calls slow-path
+  * code if necessary).
+  */
+ JEMALLOC_INLINE arena_t *
+ choose_arena(void)
+ {
+ 	arena_t *ret;
+ 
+ 	ret = ARENA_GET();
+ 	if (ret == NULL) {
+ 		ret = choose_arena_hard();
+ 		assert(ret != NULL);
+ 	}
+ 
+ 	return (ret);
+ }
+ 
+ #if (defined(JEMALLOC_STATS) && defined(NO_TLS))
+ JEMALLOC_INLINE thread_allocated_t *
+ thread_allocated_get(void)
+ {
+ 	thread_allocated_t *thread_allocated = (thread_allocated_t *)
+ 	    pthread_getspecific(thread_allocated_tsd);
+ 
+ 	if (thread_allocated == NULL)
+ 		return (thread_allocated_get_hard());
+ 	return (thread_allocated);
+ }
+ #endif
+ #endif
+ 
+ #include "jemalloc/internal/bitmap.h"
+ #include "jemalloc/internal/rtree.h"
+ #include "jemalloc/internal/tcache.h"
+ #include "jemalloc/internal/arena.h"
+ #include "jemalloc/internal/hash.h"
+ #ifdef JEMALLOC_ZONE
+ #include "jemalloc/internal/zone.h"
+ #endif
+ 
+ #ifndef JEMALLOC_ENABLE_INLINE
+ void	*imalloc(size_t size);
+ void	*icalloc(size_t size);
+ void	*ipalloc(size_t usize, size_t alignment, bool zero);
+ size_t	isalloc(const void *ptr);
+ #  ifdef JEMALLOC_IVSALLOC
+ size_t	ivsalloc(const void *ptr);
+ #  endif
+ void	idalloc(void *ptr);
+ void	*iralloc(void *ptr, size_t size, size_t extra, size_t alignment,
+     bool zero, bool no_move);
+ #endif
+ 
+ #if (defined(JEMALLOC_ENABLE_INLINE) || defined(JEMALLOC_C_))
+ JEMALLOC_INLINE void *
+ imalloc(size_t size)
+ {
+ 
+ 	assert(size != 0);
+ 
+ 	if (size <= arena_maxclass)
+ 		return (arena_malloc(size, false));
+ 	else
+ 		return (huge_malloc(size, false));
+ }
+ 
+ JEMALLOC_INLINE void *
+ icalloc(size_t size)
+ {
+ 
+ 	if (size <= arena_maxclass)
+ 		return (arena_malloc(size, true));
+ 	else
+ 		return (huge_malloc(size, true));
+ }
+ 
+ JEMALLOC_INLINE void *
+ ipalloc(size_t usize, size_t alignment, bool zero)
+ {
+ 	void *ret;
+ 
+ 	assert(usize != 0);
+ 	assert(usize == sa2u(usize, alignment, NULL));
+ 
+ 	if (usize <= arena_maxclass && alignment <= PAGE_SIZE)
+ 		ret = arena_malloc(usize, zero);
+ 	else {
+ 		size_t run_size
+ #ifdef JEMALLOC_CC_SILENCE
+ 		    = 0
+ #endif
+ 		    ;
+ 
+ 		/*
+ 		 * Ideally we would only ever call sa2u() once per aligned
+ 		 * allocation request, and the caller of this function has
+ 		 * already done so once.  However, it's rather burdensome to
+ 		 * require every caller to pass in run_size, especially given
+ 		 * that it's only relevant to large allocations.  Therefore,
+ 		 * just call it again here in order to get run_size.
+ 		 */
+ 		sa2u(usize, alignment, &run_size);
+ 		if (run_size <= arena_maxclass) {
+ 			ret = arena_palloc(choose_arena(), usize, run_size,
+ 			    alignment, zero);
+ 		} else if (alignment <= chunksize)
+ 			ret = huge_malloc(usize, zero);
+ 		else
+ 			ret = huge_palloc(usize, alignment, zero);
+ 	}
+ 
+ 	assert(((uintptr_t)ret & (alignment - 1)) == 0);
+ 	return (ret);
+ }
+ 
+ JEMALLOC_INLINE size_t
+ isalloc(const void *ptr)
+ {
+ 	size_t ret;
+ 	arena_chunk_t *chunk;
+ 
+ 	assert(ptr != NULL);
+ 
+ 	chunk = (arena_chunk_t *)CHUNK_ADDR2BASE(ptr);
+ 	if (chunk != ptr) {
+ 		/* Region. */
+ 		dassert(chunk->arena->magic == ARENA_MAGIC);
+ 
+ #ifdef JEMALLOC_PROF
+ 		ret = arena_salloc_demote(ptr);
+ #else
+ 		ret = arena_salloc(ptr);
+ #endif
+ 	} else
+ 		ret = huge_salloc(ptr);
+ 
+ 	return (ret);
+ }
+ 
+ #ifdef JEMALLOC_IVSALLOC
+ JEMALLOC_INLINE size_t
+ ivsalloc(const void *ptr)
+ {
+ 
+ 	/* Return 0 if ptr is not within a chunk managed by jemalloc. */
+ 	if (rtree_get(chunks_rtree, (uintptr_t)CHUNK_ADDR2BASE(ptr)) == NULL)
+ 		return (0);
+ 
+ 	return (isalloc(ptr));
+ }
+ #endif
+ 
+ JEMALLOC_INLINE void
+ idalloc(void *ptr)
+ {
+ 	arena_chunk_t *chunk;
+ 
+ 	assert(ptr != NULL);
+ 
+ 	chunk = (arena_chunk_t *)CHUNK_ADDR2BASE(ptr);
+ 	if (chunk != ptr)
+ 		arena_dalloc(chunk->arena, chunk, ptr);
+ 	else
+ 		huge_dalloc(ptr, true);
+ }
+ 
+ JEMALLOC_INLINE void *
+ iralloc(void *ptr, size_t size, size_t extra, size_t alignment, bool zero,
+     bool no_move)
+ {
+ 	void *ret;
+ 	size_t oldsize;
+ 
+ 	assert(ptr != NULL);
+ 	assert(size != 0);
+ 
+ 	oldsize = isalloc(ptr);
+ 
+ 	if (alignment != 0 && ((uintptr_t)ptr & ((uintptr_t)alignment-1))
+ 	    != 0) {
+ 		size_t usize, copysize;
+ 
+ 		/*
+ 		 * Existing object alignment is inadquate; allocate new space
+ 		 * and copy.
+ 		 */
+ 		if (no_move)
+ 			return (NULL);
+ 		usize = sa2u(size + extra, alignment, NULL);
+ 		if (usize == 0)
+ 			return (NULL);
+ 		ret = ipalloc(usize, alignment, zero);
+ 		if (ret == NULL) {
+ 			if (extra == 0)
+ 				return (NULL);
+ 			/* Try again, without extra this time. */
+ 			usize = sa2u(size, alignment, NULL);
+ 			if (usize == 0)
+ 				return (NULL);
+ 			ret = ipalloc(usize, alignment, zero);
+ 			if (ret == NULL)
+ 				return (NULL);
+ 		}
+ 		/*
+ 		 * Copy at most size bytes (not size+extra), since the caller
+ 		 * has no expectation that the extra bytes will be reliably
+ 		 * preserved.
+ 		 */
+ 		copysize = (size < oldsize) ? size : oldsize;
+ 		memcpy(ret, ptr, copysize);
+ 		idalloc(ptr);
+ 		return (ret);
+ 	}
+ 
+ 	if (no_move) {
+ 		if (size <= arena_maxclass) {
+ 			return (arena_ralloc_no_move(ptr, oldsize, size,
+ 			    extra, zero));
+ 		} else {
+ 			return (huge_ralloc_no_move(ptr, oldsize, size,
+ 			    extra));
+ 		}
+ 	} else {
+ 		if (size + extra <= arena_maxclass) {
+ 			return (arena_ralloc(ptr, oldsize, size, extra,
+ 			    alignment, zero));
+ 		} else {
+ 			return (huge_ralloc(ptr, oldsize, size, extra,
+ 			    alignment, zero));
+ 		}
+ 	}
+ }
+ #endif
+ 
+ #include "jemalloc/internal/prof.h"
+ 
+ #undef JEMALLOC_H_INLINES
+ /******************************************************************************/
*** jemalloc.tmp/include/jemalloc/internal/mutex.h	Thu Jan  1 00:00:00 1970
--- jemalloc/include/jemalloc/internal/mutex.h	Thu Jan  1 00:00:00 1970
***************
*** 1,7 ****
  /******************************************************************************/
  #ifdef JEMALLOC_H_TYPES
  
! #ifdef JEMALLOC_OSSPIN
  typedef OSSpinLock malloc_mutex_t;
  #else
  typedef pthread_mutex_t malloc_mutex_t;
--- 1,10 ----
  /******************************************************************************/
  #ifdef JEMALLOC_H_TYPES
  
! #ifdef _WIN32
! #define malloc_mutex_t CRITICAL_SECTION
! #define malloc_spinlock_t CRITICAL_SECTION
! #elif defined(JEMALLOC_OSSPIN)
  typedef OSSpinLock malloc_mutex_t;
  #else
  typedef pthread_mutex_t malloc_mutex_t;
***************
*** 46,52 ****
  {
  
  	if (isthreaded) {
! #ifdef JEMALLOC_OSSPIN
  		OSSpinLockLock(mutex);
  #else
  		pthread_mutex_lock(mutex);
--- 49,57 ----
  {
  
  	if (isthreaded) {
! #if defined(_WIN32)
!                 EnterCriticalSection(mutex);
! #elif define(JEMALLOC_OSSPIN)
  		OSSpinLockLock(mutex);
  #else
  		pthread_mutex_lock(mutex);
***************
*** 59,65 ****
  {
  
  	if (isthreaded) {
! #ifdef JEMALLOC_OSSPIN
  		return (OSSpinLockTry(mutex) == false);
  #else
  		return (pthread_mutex_trylock(mutex) != 0);
--- 64,72 ----
  {
  
  	if (isthreaded) {
! #if defined(_WIN32)
! 	    return TryEnterCriticalSection(mutex);
! #elif defined(JEMALLOC_OSSPIN)
  		return (OSSpinLockTry(mutex) == false);
  #else
  		return (pthread_mutex_trylock(mutex) != 0);
***************
*** 73,79 ****
  {
  
  	if (isthreaded) {
! #ifdef JEMALLOC_OSSPIN
  		OSSpinLockUnlock(mutex);
  #else
  		pthread_mutex_unlock(mutex);
--- 80,88 ----
  {
  
  	if (isthreaded) {
! #if defined(_WIN32)
! 	        LeaveCriticalSection(mutex);
! #elif defined(JEMALLOC_OSSPIN)
  		OSSpinLockUnlock(mutex);
  #else
  		pthread_mutex_unlock(mutex);
*** jemalloc.tmp/include/jemalloc/internal/prn_.h	Thu Jan  1 00:00:00 1970
--- jemalloc/include/jemalloc/internal/prn_.h	Thu Jan  1 00:00:00 1970
***************
*** 0 ****
--- 1,60 ----
+ /******************************************************************************/
+ #ifdef JEMALLOC_H_TYPES
+ 
+ /*
+  * Simple linear congruential pseudo-random number generator:
+  *
+  *   prn(y) = (a*x + c) % m
+  *
+  * where the following constants ensure maximal period:
+  *
+  *   a == Odd number (relatively prime to 2^n), and (a-1) is a multiple of 4.
+  *   c == Odd number (relatively prime to 2^n).
+  *   m == 2^32
+  *
+  * See Knuth's TAOCP 3rd Ed., Vol. 2, pg. 17 for details on these constraints.
+  *
+  * This choice of m has the disadvantage that the quality of the bits is
+  * proportional to bit position.  For example. the lowest bit has a cycle of 2,
+  * the next has a cycle of 4, etc.  For this reason, we prefer to use the upper
+  * bits.
+  *
+  * Macro parameters:
+  *   uint32_t r          : Result.
+  *   unsigned lg_range   : (0..32], number of least significant bits to return.
+  *   uint32_t state      : Seed value.
+  *   const uint32_t a, c : See above discussion.
+  */
+ #define prn32(r, lg_range, state, a, c) do {				\
+ 	assert(lg_range > 0);						\
+ 	assert(lg_range <= 32);						\
+ 									\
+ 	r = (state * (a)) + (c);					\
+ 	state = r;							\
+ 	r >>= (32 - lg_range);						\
+ } while (false)
+ 
+ /* Same as prn32(), but 64 bits of pseudo-randomness, using uint64_t. */
+ #define prn64(r, lg_range, state, a, c) do {				\
+ 	assert(lg_range > 0);						\
+ 	assert(lg_range <= 64);						\
+ 									\
+ 	r = (state * (a)) + (c);					\
+ 	state = r;							\
+ 	r >>= (64 - lg_range);						\
+ } while (false)
+ 
+ #endif /* JEMALLOC_H_TYPES */
+ /******************************************************************************/
+ #ifdef JEMALLOC_H_STRUCTS
+ 
+ #endif /* JEMALLOC_H_STRUCTS */
+ /******************************************************************************/
+ #ifdef JEMALLOC_H_EXTERNS
+ 
+ #endif /* JEMALLOC_H_EXTERNS */
+ /******************************************************************************/
+ #ifdef JEMALLOC_H_INLINES
+ 
+ #endif /* JEMALLOC_H_INLINES */
+ /******************************************************************************/
*** jemalloc.tmp/include/jemalloc/jemalloc.h	Thu Jan  1 00:00:00 1970
--- jemalloc/include/jemalloc/jemalloc.h	Thu Jan  1 00:00:00 1970
***************
*** 0 ****
--- 1,80 ----
+ #ifndef JEMALLOC_H_
+ #define	JEMALLOC_H_
+ #ifdef __cplusplus
+ extern "C" {
+ #endif
+ 
+ #include <limits.h>
+ #include <strings.h>
+ 
+ #define	JEMALLOC_VERSION "2.2.5"
+ #define	JEMALLOC_VERSION_MAJOR 2
+ #define	JEMALLOC_VERSION_MINOR 2
+ #define	JEMALLOC_VERSION_BUGFIX 5
+ #define	JEMALLOC_VERSION_NREV 0
+ 
+ #include "jemalloc_defs.h"
+ #ifndef JEMALLOC_P
+ #  define JEMALLOC_P(s) s
+ #endif
+ 
+ #define	ALLOCM_LG_ALIGN(la)	(la)
+ #if LG_SIZEOF_PTR == 2
+ #define	ALLOCM_ALIGN(a)	(ffs(a)-1)
+ #else
+ #define	ALLOCM_ALIGN(a)	((a < (size_t)INT_MAX) ? ffs(a)-1 : ffs(a>>32)+31)
+ #endif
+ #define	ALLOCM_ZERO	((int)0x40)
+ #define	ALLOCM_NO_MOVE	((int)0x80)
+ 
+ #define	ALLOCM_SUCCESS		0
+ #define	ALLOCM_ERR_OOM		1
+ #define	ALLOCM_ERR_NOT_MOVED	2
+ 
+ void xabort(void);
+ typedef void (*malloc_abort_cb_t)(void);
+ void set_malloc_abort_cb(malloc_abort_cb_t cb);
+ #ifdef _WIN32
+ void *(*malloc_real)(size_t);
+ void* (*calloc_real)(size_t, size_t);
+ void (*free_real)(void*);
+ void* (*realloc_real)(void*, size_t);
+ void *(*memalign_real)(size_t a, size_t s);
+ int (*posix_memalign_real)(void** r, size_t a, size_t s);
+ void *(*_calloc_impl_real)(size_t, size_t);
+ void (*_heap_term_real)(void);
+ size_t (*_msize_real)(void *);
+ #endif
+ 
+ extern const char	*JEMALLOC_P(malloc_conf);
+ extern void		(*JEMALLOC_P(malloc_message))(void *, const char *);
+ 
+ void	*JEMALLOC_P(malloc)(size_t size) JEMALLOC_ATTR(malloc);
+ void	*JEMALLOC_P(calloc)(size_t num, size_t size) JEMALLOC_ATTR(malloc);
+ int	JEMALLOC_P(posix_memalign)(void **memptr, size_t alignment, size_t size)
+     JEMALLOC_ATTR(nonnull(1));
+ void	*JEMALLOC_P(realloc)(void *ptr, size_t size);
+ void	JEMALLOC_P(free)(void *ptr);
+ 
+ size_t	JEMALLOC_P(malloc_usable_size)(const void *ptr);
+ void	JEMALLOC_P(malloc_stats_print)(void (*write_cb)(void *, const char *),
+     void *cbopaque, const char *opts);
+ int	JEMALLOC_P(mallctl)(const char *name, void *oldp, size_t *oldlenp,
+     void *newp, size_t newlen);
+ int	JEMALLOC_P(mallctlnametomib)(const char *name, size_t *mibp,
+     size_t *miblenp);
+ int	JEMALLOC_P(mallctlbymib)(const size_t *mib, size_t miblen, void *oldp,
+     size_t *oldlenp, void *newp, size_t newlen);
+ 
+ int	JEMALLOC_P(allocm)(void **ptr, size_t *rsize, size_t size, int flags)
+     JEMALLOC_ATTR(nonnull(1));
+ int	JEMALLOC_P(rallocm)(void **ptr, size_t *rsize, size_t size,
+     size_t extra, int flags) JEMALLOC_ATTR(nonnull(1));
+ int	JEMALLOC_P(sallocm)(const void *ptr, size_t *rsize, int flags)
+     JEMALLOC_ATTR(nonnull(1));
+ int	JEMALLOC_P(dallocm)(void *ptr, int flags) JEMALLOC_ATTR(nonnull(1));
+ 
+ #ifdef __cplusplus
+ };
+ #endif
+ #endif /* JEMALLOC_H_ */
*** jemalloc.tmp/include/jemalloc/jemalloc_defs.h	Thu Jan  1 00:00:00 1970
--- jemalloc/include/jemalloc/jemalloc_defs.h	Thu Jan  1 00:00:00 1970
***************
*** 0 ****
--- 1,176 ----
+ #include "config.h"
+ #ifndef JEMALLOC_DEFS_H_
+ #define	JEMALLOC_DEFS_H_
+ 
+ /*
+  * If JEMALLOC_PREFIX is defined, it will cause all public APIs to be prefixed.
+  * This makes it possible, with some care, to use multiple allocators
+  * simultaneously.
+  *
+  * In many cases it is more convenient to manually prefix allocator function
+  * calls than to let macros do it automatically, particularly when using
+  * multiple allocators simultaneously.  Define JEMALLOC_MANGLE before
+  * #include'ing jemalloc.h in order to cause name mangling that corresponds to
+  * the API prefixing.
+  */
+ /* #undef JEMALLOC_PREFIX */
+ /* #undef JEMALLOC_CPREFIX */
+ #if (defined(JEMALLOC_PREFIX) && defined(JEMALLOC_MANGLE))
+ /* #undef JEMALLOC_P */
+ #endif
+ 
+ #define JEMALLOC_REALLOC0_RET_NULL
+ /*
+  * JEMALLOC_PRIVATE_NAMESPACE is used as a prefix for all library-private APIs.
+  * For shared libraries, symbol visibility mechanisms prevent these symbols
+  * from being exported, but for static libraries, naming collisions are a real
+  * possibility.
+  */
+ #define JEMALLOC_PRIVATE_NAMESPACE ""
+ #define JEMALLOC_N(string_that_no_one_should_want_to_use_as_a_jemalloc) je_##string_that_no_one_should_want_to_use_as_a_jemalloc
+ #define JEMALLOC_P(a) je_##a
+ 
+ /*
+  * Hyper-threaded CPUs may need a special instruction inside spin loops in
+  * order to yield to another virtual CPU.
+  */
+ #define CPU_SPINWAIT _mm_pause()
+ 
+ /*
+  * Defined if OSAtomic*() functions are available, as provided by Darwin, and
+  * documented in the atomic(3) manual page.
+  */
+ #undef JEMALLOC_OSATOMIC
+ 
+ /*
+  * Defined if OSSpin*() functions are available, as provided by Darwin, and
+  * documented in the spinlock(3) manual page.
+  */
+ #undef JEMALLOC_OSSPIN
+ 
+ /* Defined if __attribute__((...)) syntax is supported. */
+ #undef JEMALLOC_HAVE_ATTR
+ #ifdef JEMALLOC_HAVE_ATTR
+ #  define JEMALLOC_ATTR(s) __attribute__((s))
+ #else
+ #  define JEMALLOC_ATTR(s)
+ #endif
+ 
+ /* JEMALLOC_CC_SILENCE enables code that silences unuseful compiler warnings. */
+ #undef JEMALLOC_CC_SILENCE
+ 
+ /*
+  * JEMALLOC_DEBUG enables assertions and other sanity checks, and disables
+  * inline functions.
+  */
+ #undef JEMALLOC_DEBUG
+ 
+ /* JEMALLOC_STATS enables statistics calculation. */
+ #undef JEMALLOC_STATS
+ 
+ /* JEMALLOC_PROF enables allocation profiling. */
+ #undef JEMALLOC_PROF
+ 
+ /* Use libunwind for profile backtracing if defined. */
+ #undef JEMALLOC_PROF_LIBUNWIND
+ 
+ /* Use libgcc for profile backtracing if defined. */
+ #undef JEMALLOC_PROF_LIBGCC
+ 
+ /* Use gcc intrinsics for profile backtracing if defined. */
+ #undef JEMALLOC_PROF_GCC
+ 
+ /*
+  * JEMALLOC_TINY enables support for tiny objects, which are smaller than one
+  * quantum.
+  */
+ #define JEMALLOC_TINY
+ 
+ /*
+  * JEMALLOC_TCACHE enables a thread-specific caching layer for small objects.
+  * This makes it possible to allocate/deallocate objects without any locking
+  * when the cache is in the steady state.
+  */
+ #define JEMALLOC_TCACHE
+ 
+ /*
+  * JEMALLOC_DSS enables use of sbrk(2) to allocate chunks from the data storage
+  * segment (DSS).
+  */
+ #undef JEMALLOC_DSS
+ 
+ /* JEMALLOC_SWAP enables mmap()ed swap file support. */
+ #undef JEMALLOC_SWAP
+ 
+ /* Support memory filling (junk/zero). */
+ #undef JEMALLOC_FILL
+ 
+ /* Support optional abort() on OOM. */
+ #undef JEMALLOC_XMALLOC
+ 
+ /* Support SYSV semantics. */
+ #undef JEMALLOC_SYSV
+ 
+ /* Support lazy locking (avoid locking unless a second thread is launched). */
+ #undef JEMALLOC_LAZY_LOCK
+ 
+ /* Determine page size at run time if defined. */
+ #undef DYNAMIC_PAGE_SHIFT
+ 
+ /* One page is 2^STATIC_PAGE_SHIFT bytes. */
+ #define STATIC_PAGE_SHIFT 12
+ 
+ /* TLS is used to map arenas and magazine caches to threads. */
+ #undef NO_TLS
+ 
+ /*
+  * JEMALLOC_IVSALLOC enables ivsalloc(), which verifies that pointers reside
+  * within jemalloc-owned chunks before dereferencing them.
+  */
+ #undef JEMALLOC_IVSALLOC
+ 
+ /*
+  * Define overrides for non-standard allocator-related functions if they
+  * are present on the system.
+  */
+ #define JEMALLOC_OVERRIDE_MEMALIGN
+ #define JEMALLOC_OVERRIDE_VALLOC
+ 
+ /*
+  * Darwin (OS X) uses zones to work around Mach-O symbol override shortcomings.
+  */
+ #undef JEMALLOC_ZONE
+ #undef JEMALLOC_ZONE_VERSION
+ 
+ /* If defined, use mremap(...MREMAP_FIXED...) for huge realloc(). */
+ #undef JEMALLOC_MREMAP_FIXED
+ 
+ /*
+  * Methods for purging unused pages differ between operating systems.
+  *
+  *   madvise(..., MADV_DONTNEED) : On Linux, this immediately discards pages,
+  *                                 such that new pages will be demand-zeroed if
+  *                                 the address region is later touched.
+  *   madvise(..., MADV_FREE) : On FreeBSD and Darwin, this marks pages as being
+  *                             unused, such that they will be discarded rather
+  *                             than swapped out.
+  */
+ #undef JEMALLOC_PURGE_MADVISE_DONTNEED
+ #undef JEMALLOC_PURGE_MADVISE_FREE
+ 
+ #ifdef __ZWIN32_64_
+ #define LG_SIZEOF 3
+ #else
+ #define LG_SIZEOF 2
+ #endif
+ 
+ /* sizeof(void *) == 2^LG_SIZEOF_PTR. */
+ #define LG_SIZEOF_PTR LG_SIZEOF
+ 
+ /* sizeof(int) == 2^LG_SIZEOF_INT. */
+ #define LG_SIZEOF_INT LG_SIZEOF
+ 
+ /* sizeof(long) == 2^LG_SIZEOF_LONG. */
+ #define LG_SIZEOF_LONG LG_SIZEOF
+ 
+ #endif /* JEMALLOC_DEFS_H_ */
*** jemalloc.tmp/src/arena.c	Thu Jan  1 00:00:00 1970
--- jemalloc/src/arena.c	Thu Jan  1 00:00:00 1970
***************
*** 778,792 ****
  			if (mapelm->bits & CHUNK_MAP_LARGE)
  				pageind += mapelm->bits >> PAGE_SHIFT;
  			else {
  				arena_run_t *run = (arena_run_t *)((uintptr_t)
  				    chunk + (uintptr_t)(pageind << PAGE_SHIFT));
  
  				assert((mapelm->bits >> PAGE_SHIFT) == 0);
  				dassert(run->magic == ARENA_RUN_MAGIC);
! 				size_t binind = arena_bin_index(arena,
  				    run->bin);
! 				arena_bin_info_t *bin_info =
! 				    &arena_bin_info[binind];
  				pageind += bin_info->run_size >> PAGE_SHIFT;
  			}
  		}
--- 778,793 ----
  			if (mapelm->bits & CHUNK_MAP_LARGE)
  				pageind += mapelm->bits >> PAGE_SHIFT;
  			else {
+ 			        size_t binind;
+ 				arena_bin_info_t *bin_info;
  				arena_run_t *run = (arena_run_t *)((uintptr_t)
  				    chunk + (uintptr_t)(pageind << PAGE_SHIFT));
  
  				assert((mapelm->bits >> PAGE_SHIFT) == 0);
  				dassert(run->magic == ARENA_RUN_MAGIC);
! 				binind = arena_bin_index(arena,
  				    run->bin);
! 				bin_info = &arena_bin_info[binind];
  				pageind += bin_info->run_size >> PAGE_SHIFT;
  			}
  		}
***************
*** 825,830 ****
--- 826,834 ----
  #elif defined(JEMALLOC_PURGE_MADVISE_FREE)
  		madvise((void *)((uintptr_t)chunk + (pageind << PAGE_SHIFT)),
  		    (npages << PAGE_SHIFT), MADV_FREE);
+ #elif defined(_WIN32)
+ 		VirtualAlloc((void *)((uintptr_t)chunk + (pageind << PAGE_SHIFT)),
+ 		    (npages << PAGE_SHIFT), MEM_RESET, PAGE_READWRITE);
  #else
  #  error "No method defined for purging unused dirty pages."
  #endif
***************
*** 1628,1639 ****
  	mapbits = chunk->map[pageind-map_bias].bits;
  	assert((mapbits & CHUNK_MAP_ALLOCATED) != 0);
  	if ((mapbits & CHUNK_MAP_LARGE) == 0) {
  		arena_run_t *run = (arena_run_t *)((uintptr_t)chunk +
  		    (uintptr_t)((pageind - (mapbits >> PAGE_SHIFT)) <<
  		    PAGE_SHIFT));
  		dassert(run->magic == ARENA_RUN_MAGIC);
! 		size_t binind = arena_bin_index(chunk->arena, run->bin);
! 		arena_bin_info_t *bin_info = &arena_bin_info[binind];
  		assert(((uintptr_t)ptr - ((uintptr_t)run +
  		    (uintptr_t)bin_info->reg0_offset)) % bin_info->reg_size ==
  		    0);
--- 1632,1645 ----
  	mapbits = chunk->map[pageind-map_bias].bits;
  	assert((mapbits & CHUNK_MAP_ALLOCATED) != 0);
  	if ((mapbits & CHUNK_MAP_LARGE) == 0) {
+ 	        size_t binind;
+ 		arena_bin_info_t *bin_info;
  		arena_run_t *run = (arena_run_t *)((uintptr_t)chunk +
  		    (uintptr_t)((pageind - (mapbits >> PAGE_SHIFT)) <<
  		    PAGE_SHIFT));
  		dassert(run->magic == ARENA_RUN_MAGIC);
! 		binind = arena_bin_index(chunk->arena, run->bin);
! 		bin_info = &arena_bin_info[binind];
  		assert(((uintptr_t)ptr - ((uintptr_t)run +
  		    (uintptr_t)bin_info->reg0_offset)) % bin_info->reg_size ==
  		    0);
***************
*** 1833,1839 ****
  arena_dalloc_bin(arena_t *arena, arena_chunk_t *chunk, void *ptr,
      arena_chunk_map_t *mapelm)
  {
! 	size_t pageind;
  	arena_run_t *run;
  	arena_bin_t *bin;
  #if (defined(JEMALLOC_FILL) || defined(JEMALLOC_STATS))
--- 1839,1846 ----
  arena_dalloc_bin(arena_t *arena, arena_chunk_t *chunk, void *ptr,
      arena_chunk_map_t *mapelm)
  {
! 	size_t pageind, binind;
! 	arena_bin_info_t *bin_info;
  	arena_run_t *run;
  	arena_bin_t *bin;
  #if (defined(JEMALLOC_FILL) || defined(JEMALLOC_STATS))
***************
*** 1845,1852 ****
  	    (mapelm->bits >> PAGE_SHIFT)) << PAGE_SHIFT));
  	dassert(run->magic == ARENA_RUN_MAGIC);
  	bin = run->bin;
! 	size_t binind = arena_bin_index(arena, bin);
! 	arena_bin_info_t *bin_info = &arena_bin_info[binind];
  #if (defined(JEMALLOC_FILL) || defined(JEMALLOC_STATS))
  	size = bin_info->reg_size;
  #endif
--- 1852,1859 ----
  	    (mapelm->bits >> PAGE_SHIFT)) << PAGE_SHIFT));
  	dassert(run->magic == ARENA_RUN_MAGIC);
  	bin = run->bin;
! 	binind = arena_bin_index(arena, bin);
! 	bin_info = &arena_bin_info[binind];
  #if (defined(JEMALLOC_FILL) || defined(JEMALLOC_STATS))
  	size = bin_info->reg_size;
  #endif
***************
*** 2659,2665 ****
  		    malloc_write("<jemalloc>: Too many small size classes (");
  		    malloc_write(u2s(nbins, 10, line_buf));
  		    malloc_write(" > max 255)\n");
! 		    abort();
  		}
  	} else
  #endif
--- 2666,2672 ----
  		    malloc_write("<jemalloc>: Too many small size classes (");
  		    malloc_write(u2s(nbins, 10, line_buf));
  		    malloc_write(" > max 255)\n");
! 		    xabort();
  		}
  	} else
  #endif
***************
*** 2668,2674 ****
  	    malloc_write("<jemalloc>: Too many small size classes (");
  	    malloc_write(u2s(nbins, 10, line_buf));
  	    malloc_write(" > max 256)\n");
! 	    abort();
  	}
  
  	/*
--- 2675,2681 ----
  	    malloc_write("<jemalloc>: Too many small size classes (");
  	    malloc_write(u2s(nbins, 10, line_buf));
  	    malloc_write(" > max 256)\n");
! 	    xabort();
  	}
  
  	/*
*** jemalloc.tmp/src/chunk_mmap.c	Thu Jan  1 00:00:00 1970
--- jemalloc/src/chunk_mmap.c	Thu Jan  1 00:00:00 1970
***************
*** 34,39 ****
--- 34,72 ----
  
  /******************************************************************************/
  
+ #ifdef _WIN32
+ /* XXX yoni: support noreserve */
+ static void *
+ pages_map(void *addr, size_t size, bool noreserve)
+ {
+         void *ret = VirtualAlloc(addr, size, MEM_COMMIT | MEM_RESERVE,
+ 	    PAGE_READWRITE);
+ 	if (addr != NULL && ret != addr)
+ 	{
+ 	    if (VirtualFree(ret, 0, MEM_RELEASE))
+ 	    {
+ 		if (opt_abort)
+ 			xabort();
+ 	    }
+ 	}
+ 	assert(ret == NULL || (addr == NULL && ret != addr)
+ 	    || (addr != NULL && ret == addr));
+ 	return (ret);
+ }
+ 
+ static void
+ pages_unmap(void *addr, size_t size)
+ {
+ 	if (VirtualFree(addr, 0, MEM_RELEASE) == 0) {
+ 	        char buf[100];
+ 		sprintf(buf, "Error in VirtualFree() GetLastError: %d\n",
+ 		    GetLastError());
+ 		JEMALLOC_P(malloc_message)(NULL, buf);
+ 		if (opt_abort)
+ 			xabort();
+ 	}
+ }
+ #else
  static void *
  pages_map(void *addr, size_t size, bool noreserve)
  {
***************
*** 65,71 ****
  			malloc_write(buf);
  			malloc_write("\n");
  			if (opt_abort)
! 				abort();
  		}
  		ret = NULL;
  	}
--- 98,104 ----
  			malloc_write(buf);
  			malloc_write("\n");
  			if (opt_abort)
! 				xabort();
  		}
  		ret = NULL;
  	}
***************
*** 87,96 ****
  		malloc_write(buf);
  		malloc_write("\n");
  		if (opt_abort)
! 			abort();
  	}
  }
  
  static void *
  chunk_alloc_mmap_slow(size_t size, bool unaligned, bool noreserve)
  {
--- 120,131 ----
  		malloc_write(buf);
  		malloc_write("\n");
  		if (opt_abort)
! 			xabort();
  	}
  }
+ #endif
  
+ #ifndef _WIN32
  static void *
  chunk_alloc_mmap_slow(size_t size, bool unaligned, bool noreserve)
  {
***************
*** 136,147 ****
  
  	return (ret);
  }
  
  static void *
  chunk_alloc_mmap_internal(size_t size, bool noreserve)
  {
  	void *ret;
! 
  	/*
  	 * Ideally, there would be a way to specify alignment to mmap() (like
  	 * NetBSD has), but in the absence of such a feature, we have to work
--- 171,228 ----
  
  	return (ret);
  }
+ #endif
  
+ #ifdef _WIN32
+ static void *chunk_aligned_alloc_win32(size_t size, bool noreserve)
+ {
+ 	void *ret;
+ 	size_t offset;
+ 	int i;
+ 	/* optimisting 1st try */
+ 	ret = pages_map(NULL, size, noreserve);
+ 	if (!(offset = CHUNK_ADDR2OFFSET(ret)))
+ 	    goto Exit;
+ 	pages_unmap(ret, 0);
+ 	/* there might be free space just after the range. try in the next
+ 	 * aligned ptr within the range we got */
+ 	if ((ret = pages_map((void*)((uintptr_t)ret+chunksize-offset),
+ 	    size, noreserve)))
+ 	{
+ 	    if (!(offset = CHUNK_ADDR2OFFSET(ret)))
+ 		goto Exit;
+ 	    pages_unmap(ret, 0);
+ 	}
+ 	/* increase the size to validate it includes an aligned range, then
+ 	 * free and retry the aligned range */
+ 	for (i=0; i<10; i++)
+ 	{
+ 	    ret = pages_map(NULL, size+chunksize, noreserve);
+ 	    if (!(offset = CHUNK_ADDR2OFFSET(ret)))
+ 		goto Exit;
+ 	    pages_unmap(ret, 0);
+ 	    if ((ret = pages_map((void *)((uintptr_t)ret+chunksize-offset),
+ 		size, noreserve)))
+ 	    {
+ 		if (!(offset = CHUNK_ADDR2OFFSET(ret)))
+ 		    goto Exit;
+ 		pages_unmap(ret, 0);
+ 	    }
+ 	}
+ 	ret = NULL;
+ Exit:
+ 	assert(ret != NULL);
+ 	return ret;
+ }
+ 
+ #endif
  static void *
  chunk_alloc_mmap_internal(size_t size, bool noreserve)
  {
  	void *ret;
! #ifdef _WIN32
!         ret = chunk_aligned_alloc_win32(size, noreserve);
! #else
  	/*
  	 * Ideally, there would be a way to specify alignment to mmap() (like
  	 * NetBSD has), but in the absence of such a feature, we have to work
***************
*** 199,205 ****
  		}
  	} else
  		ret = chunk_alloc_mmap_slow(size, false, noreserve);
! 
  	return (ret);
  }
  
--- 280,286 ----
  		}
  	} else
  		ret = chunk_alloc_mmap_slow(size, false, noreserve);
! #endif
  	return (ret);
  }
  
*** jemalloc.tmp/src/chunk_swap.c	Thu Jan  1 00:00:00 1970
--- jemalloc/src/chunk_swap.c	Thu Jan  1 00:00:00 1970
***************
*** 321,327 ****
  			malloc_write(buf);
  			malloc_write("\n");
  			if (opt_abort)
! 				abort();
  			if (munmap(vaddr, voff) == -1) {
  				buferror(errno, buf, sizeof(buf));
  				malloc_write("<jemalloc>: Error in munmap(): ");
--- 321,327 ----
  			malloc_write(buf);
  			malloc_write("\n");
  			if (opt_abort)
! 				xabort();
  			if (munmap(vaddr, voff) == -1) {
  				buferror(errno, buf, sizeof(buf));
  				malloc_write("<jemalloc>: Error in munmap(): ");
*** jemalloc.tmp/src/ckh.c	Thu Jan  1 00:00:00 1970
--- jemalloc/src/ckh.c	Thu Jan  1 00:00:00 1970
***************
*** 545,551 ****
  	assert(hash1 != NULL);
  	assert(hash2 != NULL);
  
! 	h = hash(key, strlen((const char *)key), 0x94122f335b332aeaLLU);
  	if (minbits <= 32) {
  		/*
  		 * Avoid doing multiple hashes, since a single hash provides
--- 545,557 ----
  	assert(hash1 != NULL);
  	assert(hash2 != NULL);
  
! 	h = hash(key, strlen((const char *)key),
! #ifdef _MSC_VER
! 	    0x94122f335b332aeaLL
! #else
! 	    0x94122f335b332aeaLLU
! #endif
! 	    );
  	if (minbits <= 32) {
  		/*
  		 * Avoid doing multiple hashes, since a single hash provides
***************
*** 556,562 ****
  	} else {
  		ret1 = h;
  		ret2 = hash(key, strlen((const char *)key),
! 		    0x8432a476666bbc13LLU);
  	}
  
  	*hash1 = ret1;
--- 562,573 ----
  	} else {
  		ret1 = h;
  		ret2 = hash(key, strlen((const char *)key),
! #ifdef _MSC_VER
! 		    0x8432a476666bbc13LL
! #else
! 		    0x8432a476666bbc13LLU
! #endif
! 		    );
  	}
  
  	*hash1 = ret1;
***************
*** 593,599 ****
  	u.i = 0;
  #endif
  	u.v = key;
! 	h = hash(&u.i, sizeof(u.i), 0xd983396e68886082LLU);
  	if (minbits <= 32) {
  		/*
  		 * Avoid doing multiple hashes, since a single hash provides
--- 604,616 ----
  	u.i = 0;
  #endif
  	u.v = key;
! 	h = hash(&u.i, sizeof(u.i),
! #ifdef _MSC_VER
! 	    0xd983396e68886082LL
! #else
! 	    0xd983396e68886082LLU
! #endif
! 	    );
  	if (minbits <= 32) {
  		/*
  		 * Avoid doing multiple hashes, since a single hash provides
***************
*** 604,610 ****
  	} else {
  		assert(SIZEOF_PTR == 8);
  		ret1 = h;
! 		ret2 = hash(&u.i, sizeof(u.i), 0x5e2be9aff8709a5dLLU);
  	}
  
  	*hash1 = ret1;
--- 621,634 ----
  	} else {
  		assert(SIZEOF_PTR == 8);
  		ret1 = h;
! 		ret2 = hash(&u.i, sizeof(u.i),
! #ifdef _MSC_VER
! 	    0x5e2be9aff8709a5dLL
! #else
! 	    0x5e2be9aff8709a5dLLU
! #endif
! 	    );
! 
  	}
  
  	*hash1 = ret1;
*** jemalloc.tmp/src/compat_win32.c	Thu Jan  1 00:00:00 1970
--- jemalloc/src/compat_win32.c	Thu Jan  1 00:00:00 1970
***************
*** 0 ****
--- 1,63 ----
+ #include <config.h>
+ #include "jemalloc/internal/jemalloc_internal.h"
+ 
+ void *win32_getspecific(pthread_key_t key)
+ {
+     return TlsGetValue(key);
+ }
+ 
+ int win32_setspecific(pthread_key_t key, const void *value)
+ {
+     TlsSetValue(key, value);
+     return 0;
+ }
+ 
+ typedef struct tls_cb_t tls_cb_t;
+ struct tls_cb_t{
+     tls_cb_t *next;
+     pthread_key_t key;
+     void (*cb)(void *);
+ };
+ static tls_cb_t *g_tls_cb;
+ 
+ int win32_key_create(pthread_key_t *key, void (*destructor)(void *))
+ {
+     tls_cb_t *cb;
+     if ((*key = TlsAlloc())==TLS_OUT_OF_INDEXES)
+ 	return -1;
+     if (!destructor)
+ 	return 0;
+     cb = base_alloc(sizeof(tls_cb_t)); /* never freed */
+     memset(cb, 0, sizeof(tls_cb_t));
+     cb->key = *key = TlsAlloc();
+     cb->next = g_tls_cb;
+     cb->cb = destructor;
+     g_tls_cb = cb;
+     return 0;
+ }
+ 
+ static void NTAPI on_tls_callback(HINSTANCE h, DWORD dwReason, PVOID pv)
+ {
+     tls_cb_t *cb;
+     int id;
+     void *val;
+     if (dwReason!=DLL_THREAD_DETACH)
+ 	return;
+     id = GetCurrentThreadId();
+     for (cb = g_tls_cb; cb; cb = cb->next)
+     {
+ 	if (!(val = win32_getspecific(cb->key)))
+ 	    continue;
+ 	win32_setspecific(cb->key, NULL);
+ 	if (cb->cb)
+ 	    cb->cb(val);
+     }
+ }
+ 
+ #pragma data_seg(push, old_seg)
+ #pragma data_seg(".CRT$XLC")
+ #pragma section(".CRT$XLC", long, read)
+ void (NTAPI *p_thread_callback_jemalloc)(
+     HINSTANCE h, DWORD dwReason, PVOID pv) = on_tls_callback;
+ #pragma data_seg(pop, old_seg)
+ 
*** jemalloc.tmp/src/ctl.c	Thu Jan  1 00:00:00 1970
--- jemalloc/src/ctl.c	Thu Jan  1 00:00:00 1970
***************
*** 213,227 ****
  /* Maximum tree depth. */
  #define	CTL_MAX_DEPTH	6
  
- #define	NAME(n)	true,	{.named = {n
- #define	CHILD(c) sizeof(c##_node) / sizeof(ctl_node_t),	c##_node}},	NULL
- #define	CTL(c)	0,				NULL}},		c##_ctl
- 
  /*
   * Only handles internal indexed nodes, since there are currently no external
   * ones.
   */
  #define	INDEX(i)	false,	{.indexed = {i##_index}},		NULL
  
  #ifdef JEMALLOC_TCACHE
  static const ctl_node_t	tcache_node[] = {
--- 213,231 ----
  /* Maximum tree depth. */
  #define	CTL_MAX_DEPTH	6
  
  /*
   * Only handles internal indexed nodes, since there are currently no external
   * ones.
   */
+ #ifdef _MSC_VER
+ #define	NAME(n)	true,	{ {n
+ #define	INDEX(i)	false,	{{NULL}, {i##_index}},		NULL
+ #else
+ #define	NAME(n)	true,	{.named = {n
  #define	INDEX(i)	false,	{.indexed = {i##_index}},		NULL
+ #endif
+ #define	CHILD(c) sizeof(c##_node) / sizeof(ctl_node_t),	c##_node}},	NULL
+ #define	CTL(c)	0,				NULL}},		c##_ctl
  
  #ifdef JEMALLOC_TCACHE
  static const ctl_node_t	tcache_node[] = {
***************
*** 313,318 ****
--- 317,324 ----
  };
  
  static const ctl_node_t arenas_bin_node[] = {
+         { false, {{NULL}, {arenas_bin_i_index}},		NULL},
+ 	{INDEX(arenas_bin_i)},
  	{INDEX(arenas_bin_i)}
  };
  
***************
*** 642,648 ****
  ctl_refresh(void)
  {
  	unsigned i;
! 	arena_t *tarenas[narenas];
  
  #ifdef JEMALLOC_STATS
  	malloc_mutex_lock(&chunks_mtx);
--- 648,659 ----
  ctl_refresh(void)
  {
  	unsigned i;
! 	static unsigned _narenas;
! 	arena_t **tarenas;
! 	if (_narenas<narenas) {
! 	     tarenas = base_alloc(narenas*sizeof(arena_t*));
! 	     _narenas = narenas;
! 	}
  
  #ifdef JEMALLOC_STATS
  	malloc_mutex_lock(&chunks_mtx);
***************
*** 970,976 ****
  	}								\
  } while (0)
  
! #define	VOID()	do {							\
  	READONLY();							\
  	WRITEONLY();							\
  } while (0)
--- 981,987 ----
  	}								\
  } while (0)
  
! #define	_VOID()	do {							\
  	READONLY();							\
  	WRITEONLY();							\
  } while (0)
***************
*** 1102,1108 ****
  	int ret;
  	tcache_t *tcache;
  
! 	VOID();
  
  	tcache = TCACHE_GET();
  	if (tcache == NULL) {
--- 1113,1119 ----
  	int ret;
  	tcache_t *tcache;
  
! 	_VOID();
  
  	tcache = TCACHE_GET();
  	if (tcache == NULL) {
***************
*** 1397,1403 ****
  		ret = EFAULT;
  		goto RETURN;
  	} else {
! 		arena_t *tarenas[narenas];
  
  		malloc_mutex_lock(&arenas_lock);
  		memcpy(tarenas, arenas, sizeof(arena_t *) * narenas);
--- 1408,1419 ----
  		ret = EFAULT;
  		goto RETURN;
  	} else {
! 	    	static unsigned _narenas;
! 		arena_t **tarenas;
! 		if (_narenas<narenas) {
! 		    tarenas = base_alloc(narenas*sizeof(arena_t*));
! 		    _narenas = narenas;
! 		}
  
  		malloc_mutex_lock(&arenas_lock);
  		memcpy(tarenas, arenas, sizeof(arena_t *) * narenas);
*** jemalloc.tmp/src/huge.c	Thu Jan  1 00:00:00 1970
--- jemalloc/src/huge.c	Thu Jan  1 00:00:00 1970
***************
*** 258,264 ****
  			malloc_write(buf);
  			malloc_write("\n");
  			if (opt_abort)
! 				abort();
  			memcpy(ret, ptr, copysize);
  			chunk_dealloc_mmap(ptr, oldsize);
  		}
--- 258,264 ----
  			malloc_write(buf);
  			malloc_write("\n");
  			if (opt_abort)
! 				xabort();
  			memcpy(ret, ptr, copysize);
  			chunk_dealloc_mmap(ptr, oldsize);
  		}
*** jemalloc.tmp/src/jemalloc.c	Thu Jan  1 00:00:00 1970
--- jemalloc/src/jemalloc.c	Thu Jan  1 00:00:00 1970
***************
*** 28,38 ****
  static pthread_t	malloc_initializer = (unsigned long)0;
  
  /* Used to avoid initialization races. */
! static malloc_mutex_t	init_lock =
! #ifdef JEMALLOC_OSSPIN
!     0
  #else
!     MALLOC_MUTEX_INITIALIZER
  #endif
      ;
  
--- 28,39 ----
  static pthread_t	malloc_initializer = (unsigned long)0;
  
  /* Used to avoid initialization races. */
! static malloc_mutex_t	init_lock
! #ifdef _WIN32
! #elif defined(JEMALLOC_OSSPIN)
!     = 0
  #else
!     = MALLOC_MUTEX_INITIALIZER
  #endif
      ;
  
***************
*** 46,58 ****
  
  /* Runtime configuration options. */
  const char	*JEMALLOC_P(malloc_conf) JEMALLOC_ATTR(visibility("default"));
  #ifdef JEMALLOC_DEBUG
  bool	opt_abort = true;
  #  ifdef JEMALLOC_FILL
  bool	opt_junk = true;
  #  endif
  #else
! bool	opt_abort = false;
  #  ifdef JEMALLOC_FILL
  bool	opt_junk = false;
  #  endif
--- 47,60 ----
  
  /* Runtime configuration options. */
  const char	*JEMALLOC_P(malloc_conf) JEMALLOC_ATTR(visibility("default"));
+ malloc_abort_cb_t malloc_abort_cb;
  #ifdef JEMALLOC_DEBUG
  bool	opt_abort = true;
  #  ifdef JEMALLOC_FILL
  bool	opt_junk = true;
  #  endif
  #else
! bool	opt_abort = true;
  #  ifdef JEMALLOC_FILL
  bool	opt_junk = false;
  #  endif
***************
*** 68,73 ****
--- 70,83 ----
  #endif
  size_t	opt_narenas = 0;
  
+ void xabort(void)
+ {
+     if (malloc_abort_cb)
+ 	malloc_abort_cb();
+     else
+ 	abort();
+ }
+ 
  /******************************************************************************/
  /* Function prototypes for non-inline static functions. */
  
***************
*** 138,144 ****
  	 */
  	malloc_write("<jemalloc>: Error initializing arena\n");
  	if (opt_abort)
! 		abort();
  
  	return (arenas[0]);
  }
--- 148,154 ----
  	 */
  	malloc_write("<jemalloc>: Error initializing arena\n");
  	if (opt_abort)
! 		xabort();
  
  	return (arenas[0]);
  }
***************
*** 213,219 ****
  int
  buferror(int errnum, char *buf, size_t buflen)
  {
! #ifdef _GNU_SOURCE
  	char *b = strerror_r(errno, buf, buflen);
  	if (b != buf) {
  		strncpy(buf, b, buflen);
--- 223,232 ----
  int
  buferror(int errnum, char *buf, size_t buflen)
  {
! /* XXX: win32 implementation */
! #ifdef _MSC_VER
!         return 0;
! #elif defined(_GNU_SOURCE)
  	char *b = strerror_r(errno, buf, buflen);
  	if (b != buf) {
  		strncpy(buf, b, buflen);
***************
*** 271,277 ****
  		    " mallctl(\"thread.{de,}allocated[p]\", ...)"
  		    " will be inaccurate\n");
  		if (opt_abort)
! 			abort();
  		return (&static_thread_allocated);
  	}
  	pthread_setspecific(thread_allocated_tsd, thread_allocated);
--- 284,290 ----
  		    " mallctl(\"thread.{de,}allocated[p]\", ...)"
  		    " will be inaccurate\n");
  		if (opt_abort)
! 			xabort();
  		return (&static_thread_allocated);
  	}
  	pthread_setspecific(thread_allocated_tsd, thread_allocated);
***************
*** 294,305 ****
--- 307,324 ----
  {
  	unsigned ret;
  	long result;
+ #ifdef _WIN32
+ 	SYSTEM_INFO info;
+ 	GetSystemInfo(&info);
+ 	result = info.dwNumberOfProcessors;
+ #else
  
  	result = sysconf(_SC_NPROCESSORS_ONLN);
  	if (result == -1) {
  		/* Error. */
  		ret = 1;
  	}
+ #endif
  	ret = (unsigned)result;
  
  	return (ret);
***************
*** 326,331 ****
--- 345,362 ----
  }
  #endif
  
+ #ifdef _WIN32
+ /* Implement xgetenv without using malloc */
+ static char env_buf[64];
+ 
+ static char *
+ xgetenv(const char *name)
+ {
+ 	if (GetEnvironmentVariableA(name, (LPSTR)&env_buf, sizeof(env_buf)) > 0)
+ 		return (env_buf);
+ 	return (NULL);
+ }
+ #endif
  /*
   * FreeBSD's pthreads implementation calls malloc(3), so the malloc
   * implementation has to take pains to avoid infinite recursion during
***************
*** 463,468 ****
--- 494,500 ----
  			}
  			break;
  		case 1: {
+ #ifndef _WIN32
  			int linklen;
  			const char *linkname =
  #ifdef JEMALLOC_PREFIX
***************
*** 485,490 ****
--- 517,523 ----
  				buf[0] = '\0';
  				opts = buf;
  			}
+ #endif
  			break;
  		}
  		case 2: {
***************
*** 496,502 ****
--- 529,539 ----
  #endif
  			    ;
  
+ #ifdef _WIN32
+ 			if ((opts = xgetenv(envname)) != NULL) {
+ #else
  			if ((opts = getenv(envname)) != NULL) {
+ #endif
  				/*
  				 * Do nothing; opts is already initialized to
  				 * the value of the MALLOC_CONF environment
***************
*** 661,666 ****
--- 698,706 ----
  {
  	arena_t *init_arenas[1];
  
+ #ifdef _WIN32
+ 	malloc_mutex_init(&init_lock);
+ #endif
  	malloc_mutex_lock(&init_lock);
  	if (malloc_initialized || malloc_initializer == pthread_self()) {
  		/*
***************
*** 686,694 ****
  	/* Get page size. */
  	{
  		long result;
! 
  		result = sysconf(_SC_PAGESIZE);
  		assert(result != -1);
  		pagesize = (size_t)result;
  
  		/*
--- 726,739 ----
  	/* Get page size. */
  	{
  		long result;
! #ifdef _WIN32
! 		SYSTEM_INFO info;
! 		GetSystemInfo(&info);
! 		result = info.dwPageSize;
! #else
  		result = sysconf(_SC_PAGESIZE);
  		assert(result != -1);
+ #endif
  		pagesize = (size_t)result;
  
  		/*
***************
*** 707,719 ****
  
  	malloc_conf_init();
  
  	/* Register fork handlers. */
  	if (pthread_atfork(jemalloc_prefork, jemalloc_postfork,
  	    jemalloc_postfork) != 0) {
  		malloc_write("<jemalloc>: Error in pthread_atfork()\n");
  		if (opt_abort)
! 			abort();
  	}
  
  	if (ctl_boot()) {
  		malloc_mutex_unlock(&init_lock);
--- 752,766 ----
  
  	malloc_conf_init();
  
+ #ifndef _WIN32
  	/* Register fork handlers. */
  	if (pthread_atfork(jemalloc_prefork, jemalloc_postfork,
  	    jemalloc_postfork) != 0) {
  		malloc_write("<jemalloc>: Error in pthread_atfork()\n");
  		if (opt_abort)
! 			xabort();
  	}
+ #endif
  
  	if (ctl_boot()) {
  		malloc_mutex_unlock(&init_lock);
***************
*** 725,731 ****
  		if (atexit(stats_print_atexit) != 0) {
  			malloc_write("<jemalloc>: Error in atexit()\n");
  			if (opt_abort)
! 				abort();
  		}
  	}
  
--- 772,778 ----
  		if (atexit(stats_print_atexit) != 0) {
  			malloc_write("<jemalloc>: Error in atexit()\n");
  			if (opt_abort)
! 				xabort();
  		}
  	}
  
***************
*** 869,874 ****
--- 916,924 ----
  
  	malloc_initialized = true;
  	malloc_mutex_unlock(&init_lock);
+ #ifdef _WIN32
+ 	malloc_mutex_destroy(&init_lock);
+ #endif
  	return (false);
  }
  
***************
*** 879,885 ****
  {
  
  	if (malloc_init_hard())
! 		abort();
  }
  #endif
  
--- 929,935 ----
  {
  
  	if (malloc_init_hard())
! 		xabort();
  }
  #endif
  
***************
*** 928,934 ****
  			if (opt_xmalloc) {
  				malloc_write("<jemalloc>: Error in malloc(): "
  				    "invalid size 0\n");
! 				abort();
  			}
  #  endif
  			ret = NULL;
--- 978,984 ----
  			if (opt_xmalloc) {
  				malloc_write("<jemalloc>: Error in malloc(): "
  				    "invalid size 0\n");
! 				xabort();
  			}
  #  endif
  			ret = NULL;
***************
*** 967,973 ****
  		if (opt_xmalloc) {
  			malloc_write("<jemalloc>: Error in malloc(): "
  			    "out of memory\n");
! 			abort();
  		}
  #endif
  		errno = ENOMEM;
--- 1017,1023 ----
  		if (opt_xmalloc) {
  			malloc_write("<jemalloc>: Error in malloc(): "
  			    "out of memory\n");
! 			xabort();
  		}
  #endif
  		errno = ENOMEM;
***************
*** 1030,1036 ****
  					malloc_write("<jemalloc>: Error in "
  					    "posix_memalign(): invalid size "
  					    "0\n");
! 					abort();
  				}
  #  endif
  				result = NULL;
--- 1080,1086 ----
  					malloc_write("<jemalloc>: Error in "
  					    "posix_memalign(): invalid size "
  					    "0\n");
! 					xabort();
  				}
  #  endif
  				result = NULL;
***************
*** 1048,1054 ****
  			if (opt_xmalloc) {
  				malloc_write("<jemalloc>: Error in "
  				    "posix_memalign(): invalid alignment\n");
! 				abort();
  			}
  #endif
  			result = NULL;
--- 1098,1104 ----
  			if (opt_xmalloc) {
  				malloc_write("<jemalloc>: Error in "
  				    "posix_memalign(): invalid alignment\n");
! 				xabort();
  			}
  #endif
  			result = NULL;
***************
*** 1095,1101 ****
  		if (opt_xmalloc) {
  			malloc_write("<jemalloc>: Error in posix_memalign(): "
  			    "out of memory\n");
! 			abort();
  		}
  #endif
  		ret = ENOMEM;
--- 1145,1151 ----
  		if (opt_xmalloc) {
  			malloc_write("<jemalloc>: Error in posix_memalign(): "
  			    "out of memory\n");
! 			xabort();
  		}
  #endif
  		ret = ENOMEM;
***************
*** 1210,1216 ****
  		if (opt_xmalloc) {
  			malloc_write("<jemalloc>: Error in calloc(): out of "
  			    "memory\n");
! 			abort();
  		}
  #endif
  		errno = ENOMEM;
--- 1260,1266 ----
  		if (opt_xmalloc) {
  			malloc_write("<jemalloc>: Error in calloc(): out of "
  			    "memory\n");
! 			xabort();
  		}
  #endif
  		errno = ENOMEM;
***************
*** 1258,1266 ****
--- 1308,1323 ----
  	if (size == 0) {
  #ifdef JEMALLOC_SYSV
  		if (opt_sysv == false)
+ 		{
  #endif
+ #ifdef JEMALLOC_REALLOC0_RET_NULL
+ 		        JEMALLOC_P(free)(ptr);
+ 		        return NULL;
+ #else
  			size = 1;
+ #endif
  #ifdef JEMALLOC_SYSV
+ 		}
  		else {
  			if (ptr != NULL) {
  #if (defined(JEMALLOC_PROF) || defined(JEMALLOC_STATS))
***************
*** 1333,1339 ****
  			if (opt_xmalloc) {
  				malloc_write("<jemalloc>: Error in realloc(): "
  				    "out of memory\n");
! 				abort();
  			}
  #endif
  			errno = ENOMEM;
--- 1390,1396 ----
  			if (opt_xmalloc) {
  				malloc_write("<jemalloc>: Error in realloc(): "
  				    "out of memory\n");
! 				xabort();
  			}
  #endif
  			errno = ENOMEM;
***************
*** 1383,1389 ****
  			if (opt_xmalloc) {
  				malloc_write("<jemalloc>: Error in realloc(): "
  				    "out of memory\n");
! 				abort();
  			}
  #endif
  			errno = ENOMEM;
--- 1440,1446 ----
  			if (opt_xmalloc) {
  				malloc_write("<jemalloc>: Error in realloc(): "
  				    "out of memory\n");
! 				xabort();
  			}
  #endif
  			errno = ENOMEM;
***************
*** 1406,1411 ****
--- 1463,1493 ----
  	return (ret);
  }
  
+ JEMALLOC_ATTR(malloc)
+ JEMALLOC_ATTR(visibility("default"))
+ void *
+ JEMALLOC_P(_recalloc)(void *ptr, size_t count, size_t size)
+ {
+ 	size_t oldsize = (ptr != NULL) ? isalloc(ptr) : 0;
+ 	size_t newsize = count * size;
+ 
+ 	/*
+ 	 * In order for all trailing bytes to be zeroed, the caller needs to
+ 	 * use calloc(), followed by recalloc().  However, the current calloc()
+ 	 * implementation only zeros the bytes requested, so if recalloc() is
+ 	 * to work 100% correctly, calloc() will need to change to zero
+ 	 * trailing bytes.
+ 	 */
+ 
+ 	ptr = JEMALLOC_P(realloc)(ptr, newsize);
+ 	if (ptr != NULL && oldsize < newsize) {
+ 		memset((void *)((uintptr_t)ptr + oldsize), 0, newsize -
+ 		    oldsize);
+ 	}
+ 
+ 	return ptr;
+ }
+ 
  JEMALLOC_ATTR(visibility("default"))
  void
  JEMALLOC_P(free)(void *ptr)
***************
*** 1648,1654 ****
  	if (opt_xmalloc) {
  		malloc_write("<jemalloc>: Error in allocm(): "
  		    "out of memory\n");
! 		abort();
  	}
  #endif
  	*ptr = NULL;
--- 1730,1736 ----
  	if (opt_xmalloc) {
  		malloc_write("<jemalloc>: Error in allocm(): "
  		    "out of memory\n");
! 		xabort();
  	}
  #endif
  	*ptr = NULL;
***************
*** 1758,1764 ****
  	if (opt_xmalloc) {
  		malloc_write("<jemalloc>: Error in rallocm(): "
  		    "out of memory\n");
! 		abort();
  	}
  #endif
  	return (ALLOCM_ERR_OOM);
--- 1840,1846 ----
  	if (opt_xmalloc) {
  		malloc_write("<jemalloc>: Error in rallocm(): "
  		    "out of memory\n");
! 		xabort();
  	}
  #endif
  	return (ALLOCM_ERR_OOM);
***************
*** 1816,1821 ****
--- 1898,2064 ----
  	return (ALLOCM_SUCCESS);
  }
  
+ #ifdef _WIN32
+ void* malloc(size_t s)
+ {
+   return malloc_real(s);
+ }
+ 
+ void  free(void* p)
+ {
+   free_real(p);
+ }
+ 
+ void* realloc(void* p, size_t s)
+ {
+   return realloc_real(p, s);
+ }
+ 
+ void* calloc(size_t n, size_t s)
+ {
+   return calloc_real(n, s);
+ }
+ 
+ void* _recalloc(void* p, size_t n, size_t s)
+ {
+     int old_size = 0, size = n*s;
+     void *result;
+     if (p)
+       old_size = _msize_real(p);
+     result = realloc_real(p, size);
+     if (result && size > old_size)
+       memset((char*)result+old_size, 0, (n*s)-old_size);
+     return result;
+ }
+ 
+ void* memalign(size_t a, size_t s)
+ {
+   return memalign_real(a, s);
+ }
+ 
+ int posix_memalign(void** r, size_t a, size_t s)
+ {
+   return posix_memalign_real(r, a, s);
+ }
+ 
+ size_t JEMALLOC_P(_msize)(void *p)
+ {
+   return JEMALLOC_P(malloc_usable_size(p));
+ }
+ 
+ size_t _msize(void *p)
+ {
+   return _msize_real(p);
+ }
+ 
+ void* _calloc_impl(size_t n, size_t s)
+ {
+   return JEMALLOC_P(calloc)(n, s);
+ }
+ 
+ void _heap_term(void)
+ {
+   _heap_term_real();
+ }
+ 
+ void *crt_orig__malloc(size_t);
+ void crt_orig__free(void*);
+ void* crt_orig__realloc(void*, size_t);
+ void* crt_orig__calloc(size_t, size_t);
+ void* crt_orig___calloc_impl(size_t, size_t);
+ void *crt_orig___aligned_malloc(size_t, size_t);
+ void *crt_orig_new(size_t);
+ void crt_orig_delete(void*);
+ void *crt_orig_newarray(size_t);
+ void crt_orig_deletearray(void*);
+ int crt_orig___heap_init(void);
+ size_t crt_orig___msize(void*);
+ void crt_orig___heap_term(void);
+ 
+ int GetenvBool(char *var, int def)
+ {
+   const char *v = xgetenv(var);
+   return v ? !strcmp(v, "1") : def;
+ }
+ 
+ // We set this to 1 because part of the CRT uses a check of _crtheap != 0
+ // to test whether the CRT has been initialized.  Once we've ripped out
+ // the allocators from libcmt, we need to provide this definition so that
+ // the rest of the CRT is still usable.
+ HANDLE _crtheap;
+ 
+ intptr_t _get_heap_handle() {
+   return (intptr_t)_crtheap;
+ }
+ 
+ int __cdecl _chvalidator_l(_locale_t plocinfo, int c, int mask)
+ {
+     return _isctype_l(c, mask, plocinfo);
+ }
+ 
+ int __cdecl _chvalidator( int c, int mask)
+ {
+         return _isctype(c, mask);
+ }
+ 
+ int _heap_init(void)
+ {
+     if (GetenvBool("JEMALLOC_DISABLE", 0))
+     {
+ 	malloc_real = crt_orig__malloc;
+ 	free_real = crt_orig__free;
+ 	calloc_real = crt_orig__calloc;
+ 	_calloc_impl_real = crt_orig___calloc_impl;
+ 	realloc_real = crt_orig__realloc;
+ 	memalign_real = crt_orig___aligned_malloc;
+ 	_heap_term_real = crt_orig___heap_term;
+ 	_msize_real = crt_orig___msize;
+ 	return crt_orig___heap_init();
+     }
+     else if (GetenvBool("JEMALLOC_DEBUG", 0))
+     {
+ 	xabort();
+ #if 0
+ 	malloc_real = je_debug_malloc;
+ 	free_real = je_debug_free;
+ 	realloc_real = je_debug_realloc;
+ 	calloc_real = je_debug_calloc;
+ 	_calloc_impl_real = je_debug_calloc;
+ 	memalign_real = je_debug_memalign;
+ 	new_real = je_debug_new;
+ 	delete_real = je_debug_delete;
+ 	newarray_real = je_debug_newarray;
+ 	deletearray_real = je_debug_deletearray;
+ 	new_nothrow_real = je_debug_new_nothrow;
+ 	newarray_nothrow_real = je_debug_newarray_nothrow;
+ 	delete_nothrow_real = je_debug_delete_nothrow;
+ 	deletearray_nothrow_real = je_debug_deletearray_nothrow;
+ 	_msize_real = je_msize;
+ 	jemalloc_debug = 1;
+ #endif
+     }
+     else
+     {
+ 	malloc_real = je_malloc;
+ 	free_real = je_free;
+ 	realloc_real = je_realloc;
+ 	calloc_real = je_calloc;
+ 	_calloc_impl_real = je_calloc;
+ 	memalign_real = je_memalign;
+ 	_msize_real = je__msize;
+ 	_crtheap = (HANDLE)1;
+ 	malloc_init_hard();
+     }
+     return 1;
+ }
+ 
+ #endif
+ 
+ void set_malloc_abort_cb(malloc_abort_cb_t cb)
+ {
+     malloc_abort_cb = cb;
+ }
+ 
  /*
   * End non-standard functions.
   */
*** jemalloc.tmp/src/jemalloc_cpp.cc	Thu Jan  1 00:00:00 1970
--- jemalloc/src/jemalloc_cpp.cc	Thu Jan  1 00:00:00 1970
***************
*** 0 ****
--- 1,20 ----
+ #include "jemalloc/internal/jemalloc_internal.h"
+ void* operator new(size_t size)
+ {
+   return malloc_real(size);
+ }
+ 
+ void operator delete(void* p)
+ {
+     free_real(p);
+ }
+ 
+ void* operator new[](size_t size)
+ {
+     return malloc_real(size);
+ }
+ 
+ void operator delete[](void* p)
+ {
+     free_real(p);
+ }
*** jemalloc.tmp/src/mutex.c	Thu Jan  1 00:00:00 1970
--- jemalloc/src/mutex.c	Thu Jan  1 00:00:00 1970
***************
*** 30,36 ****
  	if (pthread_create_fptr == NULL) {
  		malloc_write("<jemalloc>: Error in dlsym(RTLD_NEXT, "
  		    "\"pthread_create\")\n");
! 		abort();
  	}
  
  	isthreaded = true;
--- 30,36 ----
  	if (pthread_create_fptr == NULL) {
  		malloc_write("<jemalloc>: Error in dlsym(RTLD_NEXT, "
  		    "\"pthread_create\")\n");
! 		xabort();
  	}
  
  	isthreaded = true;
***************
*** 55,61 ****
  bool
  malloc_mutex_init(malloc_mutex_t *mutex)
  {
! #ifdef JEMALLOC_OSSPIN
  	*mutex = 0;
  #else
  	pthread_mutexattr_t attr;
--- 55,64 ----
  bool
  malloc_mutex_init(malloc_mutex_t *mutex)
  {
! #ifdef _WIN32
!         if (! InitializeCriticalSectionAndSpinCount(mutex, _CRT_SPINCOUNT))
! 	        return (true);
! #elif defined(JEMALLOC_OSSPIN)
  	*mutex = 0;
  #else
  	pthread_mutexattr_t attr;
***************
*** 80,90 ****
  void
  malloc_mutex_destroy(malloc_mutex_t *mutex)
  {
! 
! #ifndef JEMALLOC_OSSPIN
  	if (pthread_mutex_destroy(mutex) != 0) {
  		malloc_write("<jemalloc>: Error in pthread_mutex_destroy()\n");
! 		abort();
  	}
  #endif
  }
--- 83,94 ----
  void
  malloc_mutex_destroy(malloc_mutex_t *mutex)
  {
! #ifdef _WIN32
!         DeleteCriticalSection(mutex);
! #elif !defined(JEMALLOC_OSSPIN)
  	if (pthread_mutex_destroy(mutex) != 0) {
  		malloc_write("<jemalloc>: Error in pthread_mutex_destroy()\n");
! 		xabort();
  	}
  #endif
  }
*** jemalloc.tmp/src/prof.c	Thu Jan  1 00:00:00 1970
--- jemalloc/src/prof.c	Thu Jan  1 00:00:00 1970
***************
*** 559,565 ****
  			malloc_write("<jemalloc>: write() failed during heap "
  			    "profile flush\n");
  			if (opt_abort)
! 				abort();
  		}
  		ret = true;
  	}
--- 559,565 ----
  			malloc_write("<jemalloc>: write() failed during heap "
  			    "profile flush\n");
  			if (opt_abort)
! 				xabort();
  		}
  		ret = true;
  	}
***************
*** 835,841 ****
  			malloc_write(filename);
  			malloc_write("\", 0644) failed\n");
  			if (opt_abort)
! 				abort();
  		}
  		goto ERROR;
  	}
--- 835,841 ----
  			malloc_write(filename);
  			malloc_write("\", 0644) failed\n");
  			if (opt_abort)
! 				xabort();
  		}
  		goto ERROR;
  	}
***************
*** 1207,1213 ****
  		    != 0) {
  			malloc_write(
  			    "<jemalloc>: Error in pthread_key_create()\n");
! 			abort();
  		}
  
  		prof_bt_max = (1U << opt_lg_prof_bt_max);
--- 1207,1213 ----
  		    != 0) {
  			malloc_write(
  			    "<jemalloc>: Error in pthread_key_create()\n");
! 			xabort();
  		}
  
  		prof_bt_max = (1U << opt_lg_prof_bt_max);
***************
*** 1223,1229 ****
  		if (atexit(prof_fdump) != 0) {
  			malloc_write("<jemalloc>: Error in atexit()\n");
  			if (opt_abort)
! 				abort();
  		}
  	}
  
--- 1223,1229 ----
  		if (atexit(prof_fdump) != 0) {
  			malloc_write("<jemalloc>: Error in atexit()\n");
  			if (opt_abort)
! 				xabort();
  		}
  	}
  
*** jemalloc.tmp/src/stats.c	Thu Jan  1 00:00:00 1970
--- jemalloc/src/stats.c	Thu Jan  1 00:00:00 1970
***************
*** 412,418 ****
  		}
  		malloc_write("<jemalloc>: Failure in mallctl(\"epoch\", "
  		    "...)\n");
! 		abort();
  	}
  
  	if (write_cb == NULL) {
--- 412,418 ----
  		}
  		malloc_write("<jemalloc>: Failure in mallctl(\"epoch\", "
  		    "...)\n");
! 		xabort();
  	}
  
  	if (write_cb == NULL) {
*** jemalloc.tmp/src/tcache.c	Thu Jan  1 00:00:00 1970
--- jemalloc/src/tcache.c	Thu Jan  1 00:00:00 1970
***************
*** 470,476 ****
  		    0) {
  			malloc_write(
  			    "<jemalloc>: Error in pthread_key_create()\n");
! 			abort();
  		}
  	}
  
--- 470,476 ----
  		    0) {
  			malloc_write(
  			    "<jemalloc>: Error in pthread_key_create()\n");
! 			xabort();
  		}
  	}
  
*** jemalloc.tmp/strip_crt.pl	Thu Jan  1 00:00:00 1970
--- jemalloc/strip_crt.pl	Thu Jan  1 00:00:00 1970
***************
*** 0 ****
--- 1,153 ----
+ #!/usr/bin/perl
+ # LICENSE_CODE ZON
+ 
+ use strict;
+ use Getopt::Long qw(GetOptions :config bundling);
+ require "/usr/local/bin/util.pl";
+ 'zutil'->import();
+ my ($keep_objs, $verbose, $help) = (0, 0, 0);
+ 
+ my $BUILDDIR = sys_get_line("jtools jpwdbinroot");
+ if ($BUILDDIR eq '') {
+     die "\$BUILDDIR not set";
+ }
+ require "$BUILDDIR/zon_config.pl";
+ 
+ sub usage
+ {
+     print "Copy libcmt.lib from $::VC_LIB_PATH and rename symbols ".
+         "(malloc et al)\n".
+         "usage: create_zcrt.pl OPTIONS\n".
+         "  --keep-objs|-k do not delete objs from local dir\n".
+         "  --help|-h print this usage\n".
+ 	"  --verbose|-v verbose mode\n";
+     exit(1);
+ }
+ 
+ GetOptions('keep-objs|k' => \$keep_objs, 'verbose|v' => \$verbose,
+     'help|h' => \$help);
+ if ($help) {
+     usage();
+ }
+ if ($verbose) {
+     $zmake::print_spawn = 1;
+ }
+ 
+ my %objs;
+ my %funcs_convert;
+ if ($::__ZWIN32_64__)
+ {
+     %objs = (
+ 	'mt_obj\malloc.obj' => ['malloc'],
+ 	'mt_obj\heapinit.obj' => ['_heap_init', '_heap_term',
+ 	'_get_heap_handle'],
+ 	'mt_obj\free.obj' => ['free'],
+ 	'mt_obj\realloc.obj' => ['realloc'],
+ 	'mt_obj\recalloc.obj' => ['_recalloc'],
+ 	'mt_obj\calloc.obj' => ['calloc'],
+ 	'mt_obj\calloc_impl.obj' => ['_calloc_impl'],
+ 	'mt_obj\align.obj' => ['_aligned_malloc'],
+ 	'mt_obj\msize.obj' => ['_msize'],
+ 	'mt_obj\new.obj' => ['??2@YAPEAX_K@Z'],
+ 	'mt_obj\delete.obj' => ['??3@YAXPEAX@Z'],
+ 	'mt_obj\new2.obj' => ['??_U@YAPEAX_K@Z'],
+ 	'mt_obj\delete2.obj' => ['??_V@YAXPEAX@Z'],
+ 	'mt_obj\newopnt.obj' => ['??2@YAPEAX_KAEBUnothrow_t@std@@@Z'],
+ 	'mt_obj\newaopnt.obj' => ['??_U@YAPEAX_KAEBUnothrow_t@std@@@Z'],
+ 	'mt_obj\delopnt.obj' => ['??3@YAXPEAXAEBUnothrow_t@std@@@Z'],
+ 	'mt_obj\delaopnt.obj' => ['??_V@YAXPEAXAEBUnothrow_t@std@@@Z'],
+     );
+     %funcs_convert = (
+ 	'??2@YAPEAX_K@Z' => 'new',
+ 	'??3@YAXPEAX@Z' => 'delete',
+ 	'??_U@YAPEAX_K@Z' => 'newarray',
+ 	'??_V@YAXPEAX@Z' => 'deletearray',
+ 	'??2@YAPEAX_KAEBUnothrow_t@std@@@Z' => 'new_nothrow',
+ 	'??_U@YAPEAX_KAEBUnothrow_t@std@@@Z' => 'newarray_nothrow',
+ 	'??3@YAXPEAXAEBUnothrow_t@std@@@Z' => 'delete_nothrow',
+ 	'??_V@YAXPEAXAEBUnothrow_t@std@@@Z' => 'deletearray_nothrow',
+     );
+ }
+ else
+ {
+     %objs = (
+ 	'mt_obj\malloc.obj' => ['_malloc'],
+ 	'mt_obj\free.obj' => ['_free'],
+ 	'mt_obj\realloc.obj' => ['_realloc'],
+ 	'mt_obj\calloc.obj' => ['_calloc'],
+ 	'mt_obj\recalloc.obj' => ['__recalloc'],
+ 	'mt_obj\calloc_impl.obj' => ['__calloc_impl'],
+ 	'mt_obj\align.obj' => ['__aligned_malloc', '__aligned_free',
+ 	    '__aligned_msize'],
+ 	'mt_obj\msize.obj' => ['__msize'],
+ 	'mt_obj\new.obj' => ['??2@YAPAXI@Z'],
+ 	'mt_obj\newopnt.obj' => ['??2@YAPAXIABUnothrow_t@std@@@Z'],
+ 	'mt_obj\delete.obj' => ['??3@YAXPAX@Z'],
+ 	'mt_obj\delopnt.obj' => ['??3@YAXPAXABUnothrow_t@std@@@Z'],
+ 	'mt_obj\new2.obj' => ['??_U@YAPAXI@Z'],
+ 	'mt_obj\newaopnt.obj' => ['??_U@YAPAXIABUnothrow_t@std@@@Z'],
+ 	'mt_obj\delete2.obj' => ['??_V@YAXPAX@Z'],
+ 	'mt_obj\delaopnt.obj' => ['??_V@YAXPAXABUnothrow_t@std@@@Z'],
+ 	'mt_obj\heapinit.obj' => ['__heap_init', '__heap_term',
+ 	'__get_heap_handle'],
+ #    'mt_obj\expand.obj' => ['__expand'],
+     );
+     %funcs_convert = (
+ 	'??2@YAPAXI@Z' => 'new',
+ 	'??2@YAPAXIABUnothrow_t@std@@@Z' => 'new_nothrow',
+ 	'??3@YAXPAX@Z' => 'delete',
+ 	'??3@YAXPAXABUnothrow_t@std@@@Z' => 'delete_nothrow',
+ 	'??_U@YAPAXI@Z' => 'newarray',
+ 	'??_U@YAPAXIABUnothrow_t@std@@@Z' => 'newarray_nothrow',
+ 	'??_V@YAXPAX@Z' => 'deletearray',
+ 	'??_V@YAXPAXABUnothrow_t@std@@@Z' => 'deletearray_nothrow');
+ }
+ 
+ sys_nofail('cp', "$::VC_LIB_PATH/libcmt.lib", '.');
+ my @all_objs = sys_get_lines("jvc lib libcmt.lib /LIST");
+ if (scalar(@all_objs) == 0) {
+     die "failed jvc lib libcmt.lib /LIST";
+ }
+ 
+ for my $path (keys %objs)
+ {
+     print "$path\n";
+     my @real_obj = grep(/\Q$path/, @all_objs);
+     if ($#real_obj != 0) {
+ 	die "found $path ".($#real_obj > 0 ? $#real_obj : 0)." times in ".
+ 	    "libcmt.lib\n";
+     }
+     my @funcs = @{$objs{$path}};
+     $path = $real_obj[0];
+     my $obj = $path;
+     $obj =~ s/(.*)\\([a-z0-9_]*\.obj)$/$2/;
+     rm_rf($obj);
+     sys_nofail('jvc', 'lib', 'libcmt.lib', "/extract:$path", '/NOLOGO');
+     sys_nofail('jvc', 'lib', 'libcmt.lib', '/ignore:4006,4221,4078',
+ 	"/remove:$path", "/NOLOGO");
+     if (!$::__ZWIN32_64__) {
+ 	sys_nofail('objcopy.exe', '--strip-debug', $obj);
+     }
+     foreach my $func (@funcs)
+     {
+ 	my $to_func = $funcs_convert{$func} ? $funcs_convert{$func} : "_$func";
+ 	print "    $func -> _crt_orig$to_func\n";
+ 	if (!$::__ZWIN32_64__)
+ 	{
+ 	    sys_nofail('objcopy.exe', '--redefine-sym',
+ 		"$func=_crt_orig_$to_func", $obj);
+ 	}
+ 	else
+ 	{
+ 	    # http://www.agner.org/optimize/#objconv
+ 	    sys_nofail("$::ZTOOLS_PATH/tools/objconv.exe", '-fcof64',
+ 		"-nr:$func:crt_orig_$to_func", $obj, $obj."2");
+ 	    sys_nofail("cp", $obj."2", $obj);
+ 	}
+     }
+     sys_nofail('jvc', 'lib', 'libcmt.lib', '/ignore:4006,4221', $obj,
+ 	"/NOLOGO");
+     if (!$keep_objs) {
+ 	rm_rf($obj);
+     }
+ }

