*** jemalloc.tmp/include/jemalloc/internal/_prn.h	Thu Jan  1 00:00:00 1970
--- jemalloc/include/jemalloc/internal/_prn.h	Thu Jan  1 00:00:00 1970
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
*** jemalloc.tmp/include/jemalloc/internal/atomic.h	Thu Jan  1 00:00:00 1970
--- jemalloc/include/jemalloc/internal/atomic.h	Thu Jan  1 00:00:00 1970
***************
*** 133,138 ****
--- 133,151 ----
  
  	return (OSAtomicAdd32(-((int32_t)x), (int32_t *)p));
  }
+ #elif defined(_MSC_VER)
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
--- 1,58 ----
+ #define _CRT_SPINCOUNT 5000
+ #define __crtInitCritSecAndSpinCount InitializeCriticalSectionAndSpinCount
+ #include <io.h>
+ #include <windows.h>
+ 
+ /* XXX check all disabled warnings */
+ #pragma warning( disable: 4267 4996 4146 4334)
+ 
+ #define	bool BOOL
+ #define	false FALSE
+ #define	true TRUE
+ #define	inline __inline
+ #define	SIZE_T_MAX SIZE_MAX
+ #define	STDERR_FILENO 2
+ #ifndef MAX_PATH
+ #define	PATH_MAX MAX_PATH
+ #endif
+ #define	vsnprintf _vsnprintf
+ #ifndef NO_TLS
+ static unsigned long tlsIndex = 0xffffffff;
+ #endif
+ 
+ #define pthread_t DWORD
+ #define pthread_key_t DWORD
+ #define pthread_key_create(tsd, func) win32_key_create(tsd, func)
+ #define pthread_setspecific(tsd, v) win32_setspecific(tsd, v)
+ #define	__thread
+ #define	pthread_self() GetCurrentThreadId()
+ #define	issetugid() 0
+ 
+ int win32_key_create(pthread_key_t *key, void (*destructor)(void*));
+ int win32_setspecific(pthread_key_t key, const void *value);
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
+ 
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
*** jemalloc.tmp/include/jemalloc/internal/hash.h	Thu Jan  1 00:00:00 1970
--- jemalloc/include/jemalloc/internal/hash.h	Thu Jan  1 00:00:00 1970
***************
*** 26,32 ****
  JEMALLOC_INLINE uint64_t
  hash(const void *key, size_t len, uint64_t seed)
  {
! 	const uint64_t m = 0xc6a4a7935bd1e995LLU;
  	const int r = 47;
  	uint64_t h = seed ^ (len * m);
  	const uint64_t *data = (const uint64_t *)key;
--- 26,38 ----
  JEMALLOC_INLINE uint64_t
  hash(const void *key, size_t len, uint64_t seed)
  {
! 	const uint64_t m =
! /* XXX: find why MSVC has this wierd behavior */
! #ifdef _MSC_VER
! 	    0xc6a4a7935bd1e995;
! #else
! 	    0xc6a4a7935bd1e995LLU;
! #endif
  	const int r = 47;
  	uint64_t h = seed ^ (len * m);
  	const uint64_t *data = (const uint64_t *)key;
*** jemalloc.tmp/include/jemalloc/internal/jemalloc_internal.h	Thu Jan  1 00:00:00 1970
--- jemalloc/include/jemalloc/internal/jemalloc_internal.h	Thu Jan  1 00:00:00 1970
***************
*** 0 ****
--- 1,793 ----
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
+ 		abort();						\
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
+ #  define inline
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
+ #include "jemalloc/internal/_prn.h"
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
+ #include "jemalloc/internal/_prn.h"
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
+ #include "jemalloc/internal/_prn.h"
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
+ #include "jemalloc/internal/_prn.h"
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
  
! #ifdef _MSC_VER
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
! #if defined(_MSC_VER)
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
! #if defined(_MSC_VER)
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
! #if defined(_MSC_VER)
! 	        LeaveCriticalSection(mutex);
! #elif defined(JEMALLOC_OSSPIN)
  		OSSpinLockUnlock(mutex);
  #else
  		pthread_mutex_unlock(mutex);
*** jemalloc.tmp/include/jemalloc/jemalloc.h	Thu Jan  1 00:00:00 1970
--- jemalloc/include/jemalloc/jemalloc.h	Thu Jan  1 00:00:00 1970
***************
*** 0 ****
--- 1,65 ----
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
--- 1,174 ----
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
+ /*
+  * JEMALLOC_PRIVATE_NAMESPACE is used as a prefix for all library-private APIs.
+  * For shared libraries, symbol visibility mechanisms prevent these symbols
+  * from being exported, but for static libraries, naming collisions are a real
+  * possibility.
+  */
+ #define JEMALLOC_PRIVATE_NAMESPACE ""
+ #define JEMALLOC_N(string_that_no_one_should_want_to_use_as_a_jemalloc) string_that_no_one_should_want_to_use_as_a_jemalloc
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
--- 826,833 ----
  #elif defined(JEMALLOC_PURGE_MADVISE_FREE)
  		madvise((void *)((uintptr_t)chunk + (pageind << PAGE_SHIFT)),
  		    (npages << PAGE_SHIFT), MADV_FREE);
+ #elif defined(_MSC_VER)
+     /* XXX currently do nothing */
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
--- 1631,1644 ----
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
--- 1838,1845 ----
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
--- 1851,1858 ----
  	    (mapelm->bits >> PAGE_SHIFT)) << PAGE_SHIFT));
  	dassert(run->magic == ARENA_RUN_MAGIC);
  	bin = run->bin;
! 	binind = arena_bin_index(arena, bin);
! 	bin_info = &arena_bin_info[binind];
  #if (defined(JEMALLOC_FILL) || defined(JEMALLOC_STATS))
  	size = bin_info->reg_size;
  #endif
*** jemalloc.tmp/src/chunk_mmap.c	Thu Jan  1 00:00:00 1970
--- jemalloc/src/chunk_mmap.c	Thu Jan  1 00:00:00 1970
***************
*** 34,39 ****
--- 34,59 ----
  
  /******************************************************************************/
  
+ #ifdef _MSC_VER
+ static void *
+ pages_map(void *addr, size_t size, int pfd)
+ {
+ 	void *ret = VirtualAlloc(addr, size, MEM_COMMIT | MEM_RESERVE,
+ 	    PAGE_READWRITE);
+ 	return ret;
+ }
+ 
+ static void
+ pages_unmap(void *addr, size_t size)
+ {
+ 	if (VirtualFree(addr, size, MEM_DECOMMIT) == 0) {
+ 		JEMALLOC_P(malloc_message)(NULL,
+ 		    ": (malloc) Error in VirtualFree()\n");
+ 		if (opt_abort)
+ 			abort();
+ 	}
+ }
+ #else
  static void *
  pages_map(void *addr, size_t size, bool noreserve)
  {
***************
*** 90,95 ****
--- 110,116 ----
  			abort();
  	}
  }
+ #endif
  
  static void *
  chunk_alloc_mmap_slow(size_t size, bool unaligned, bool noreserve)
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
--- 1,13 ----
+ #include <config.h>
+ #include "jemalloc/internal/compat_win32.h"
+ 
+ int win32_setspecific(pthread_key_t key, const void *value)
+ {
+     return 0;
+ }
+ 
+ int win32_setspecific(pthread_key_t *key, void (*destructor)(void*))
+ {
+     return 0;
+ }
+ 
*** jemalloc.tmp/src/ctl.c	Thu Jan  1 00:00:00 1970
--- jemalloc/src/ctl.c	Thu Jan  1 00:00:00 1970
***************
*** 213,228 ****
  /* Maximum tree depth. */
  #define	CTL_MAX_DEPTH	6
  
  #define	NAME(n)	true,	{.named = {n
  #define	CHILD(c) sizeof(c##_node) / sizeof(ctl_node_t),	c##_node}},	NULL
  #define	CTL(c)	0,				NULL}},		c##_ctl
  
- /*
-  * Only handles internal indexed nodes, since there are currently no external
-  * ones.
-  */
- #define	INDEX(i)	false,	{.indexed = {i##_index}},		NULL
- 
  #ifdef JEMALLOC_TCACHE
  static const ctl_node_t	tcache_node[] = {
  	{NAME("flush"),		CTL(tcache_flush)}
--- 213,228 ----
  /* Maximum tree depth. */
  #define	CTL_MAX_DEPTH	6
  
+ #ifdef _MSC_VER
+ #define	NAME(n)	true,	{ {n
+ #define	INDEX(i)	false,	{{NULL}, {i##_index}},		NULL
+ #else
  #define	NAME(n)	true,	{.named = {n
+ #define	INDEX(i)	false,	{.indexed = {i##_index}},		NULL
+ #endif
  #define	CHILD(c) sizeof(c##_node) / sizeof(ctl_node_t),	c##_node}},	NULL
  #define	CTL(c)	0,				NULL}},		c##_ctl
  
  #ifdef JEMALLOC_TCACHE
  static const ctl_node_t	tcache_node[] = {
  	{NAME("flush"),		CTL(tcache_flush)}
***************
*** 313,318 ****
--- 313,320 ----
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
--- 644,655 ----
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
--- 977,983 ----
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
--- 1109,1115 ----
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
--- 1404,1415 ----
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
*** 241,246 ****
--- 241,247 ----
  		 * this one removes it from the tree.
  		 */
  		huge_dalloc(ptr, false);
+ 		/* XXX add _MSC_VER support */
  		if (mremap(ptr, oldsize, newsize, MREMAP_MAYMOVE|MREMAP_FIXED,
  		    ret) == MAP_FAILED) {
  			/*
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
! #ifdef _MSC_VER
! #elif defined(JEMALLOC_OSSPIN)
!     = 0
  #else
!     = MALLOC_MUTEX_INITIALIZER
  #endif
      ;
  
***************
*** 213,219 ****
  int
  buferror(int errnum, char *buf, size_t buflen)
  {
! #ifdef _GNU_SOURCE
  	char *b = strerror_r(errno, buf, buflen);
  	if (b != buf) {
  		strncpy(buf, b, buflen);
--- 214,223 ----
  int
  buferror(int errnum, char *buf, size_t buflen)
  {
! /* XXX: find win32 prelacement */
! #ifdef _MSC_VER
!         return 0;
! #elif defined(_GNU_SOURCE)
  	char *b = strerror_r(errno, buf, buflen);
  	if (b != buf) {
  		strncpy(buf, b, buflen);
***************
*** 294,305 ****
--- 298,315 ----
  {
  	unsigned ret;
  	long result;
+ #ifdef _MSC_VER
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
*** 463,468 ****
--- 473,479 ----
  			}
  			break;
  		case 1: {
+ #ifndef _MSC_VER
  			int linklen;
  			const char *linkname =
  #ifdef JEMALLOC_PREFIX
***************
*** 485,490 ****
--- 496,502 ----
  				buf[0] = '\0';
  				opts = buf;
  			}
+ #endif
  			break;
  		}
  		case 2: {
***************
*** 661,666 ****
--- 673,681 ----
  {
  	arena_t *init_arenas[1];
  
+ #ifdef _MSC_VER
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
--- 701,714 ----
  	/* Get page size. */
  	{
  		long result;
! #ifdef _MSC_VER
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
*** 707,712 ****
--- 727,733 ----
  
  	malloc_conf_init();
  
+ #ifndef _MSC_VER
  	/* Register fork handlers. */
  	if (pthread_atfork(jemalloc_prefork, jemalloc_postfork,
  	    jemalloc_postfork) != 0) {
***************
*** 714,719 ****
--- 735,741 ----
  		if (opt_abort)
  			abort();
  	}
+ #endif
  
  	if (ctl_boot()) {
  		malloc_mutex_unlock(&init_lock);
***************
*** 869,874 ****
--- 891,899 ----
  
  	malloc_initialized = true;
  	malloc_mutex_unlock(&init_lock);
+ #ifdef _MSC_VER
+ 	malloc_mutex_destroy(&init_lock);
+ #endif
  	return (false);
  }
  
***************
*** 891,896 ****
--- 916,962 ----
   * Begin malloc(3)-compatible functions.
   */
  
+ #ifdef _MSC_VER
+ HANDLE _crtheap;
+ 
+ intptr_t _get_heap_handle() {
+   return (intptr_t)_crtheap;
+ }
+ 
+ int __cdecl _chvalidator_l(
+         _locale_t plocinfo,
+         int c,
+         int mask
+         )
+ {
+     return _isctype_l(c, mask, plocinfo);
+ }
+ 
+ int __cdecl _chvalidator(
+         int c,
+         int mask
+         )
+ {
+         return _isctype(c, mask);
+ }
+ 
+ int _heap_init(void)
+ {
+     _crtheap = (HANDLE)1;
+     return 1;
+ }
+ 
+ size_t _msize(void *p)
+ {
+   return JEMALLOC_P(malloc_usable_size(p));
+ }
+ 
+ void* _calloc_impl(size_t n, size_t s)
+ {
+   return JEMALLOC_P(calloc)(n, s);
+ }
+ #endif
+ 
  JEMALLOC_ATTR(malloc)
  JEMALLOC_ATTR(visibility("default"))
  void *
***************
*** 1406,1411 ****
--- 1472,1502 ----
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
*** jemalloc.tmp/src/mutex.c	Thu Jan  1 00:00:00 1970
--- jemalloc/src/mutex.c	Thu Jan  1 00:00:00 1970
***************
*** 18,23 ****
--- 18,24 ----
   * process goes multi-threaded.
   */
  
+ /* XXX add win32 impl */
  #ifdef JEMALLOC_LAZY_LOCK
  static int (*pthread_create_fptr)(pthread_t *__restrict, const pthread_attr_t *,
      void *(*)(void *), void *__restrict);
***************
*** 55,61 ****
  bool
  malloc_mutex_init(malloc_mutex_t *mutex)
  {
! #ifdef JEMALLOC_OSSPIN
  	*mutex = 0;
  #else
  	pthread_mutexattr_t attr;
--- 56,65 ----
  bool
  malloc_mutex_init(malloc_mutex_t *mutex)
  {
! #ifdef _MSC_VER
!         if (! __crtInitCritSecAndSpinCount(mutex, _CRT_SPINCOUNT))
! 	        return (true);
! #elif defined(JEMALLOC_OSSPIN)
  	*mutex = 0;
  #else
  	pthread_mutexattr_t attr;
***************
*** 80,87 ****
  void
  malloc_mutex_destroy(malloc_mutex_t *mutex)
  {
! 
! #ifndef JEMALLOC_OSSPIN
  	if (pthread_mutex_destroy(mutex) != 0) {
  		malloc_write("<jemalloc>: Error in pthread_mutex_destroy()\n");
  		abort();
--- 84,92 ----
  void
  malloc_mutex_destroy(malloc_mutex_t *mutex)
  {
! #ifdef _MSC_VER
!         DeleteCriticalSection(mutex);
! #elif !defined(JEMALLOC_OSSPIN)
  	if (pthread_mutex_destroy(mutex) != 0) {
  		malloc_write("<jemalloc>: Error in pthread_mutex_destroy()\n");
  		abort();
