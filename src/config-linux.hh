// -*- mode: C++; c-basic-offset: 2; tab-width: 2; indent-tabs-mode: nil -*-
# if !defined dkt_config_hh
# define      dkt_config_hh

# define HAVE_EPOLL 1
# define HAVE_POLL 1
# define HAVE_PROCFS 1

# define USE_POLL 1
# define USE_DLADDR 1
# define USE_SYSLOG 0
# define USE_SYS 1

__BEGIN_DECLS
# ifndef HAVE_GETPROGNAME
# ifdef HAVE_PROCFS
const char8_t* getprogname();
# endif // HAVE_PROCFS
# endif // HAVE_GETPROGNAME
__END_DECLS

# endif
