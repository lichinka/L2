/* config.h.  Generated from config.h.in by configure.  */
/* config.h.in.  Generated from configure.ac by autoheader.  */

/* Define to dummy `main' function (if any) required to link to the Fortran
   libraries. */
/* #undef FC_DUMMY_MAIN */

/* Define if F77 and FC dummy `main' functions are identical. */
/* #undef FC_DUMMY_MAIN_EQ_F77 */

/* Define to a macro mangling the given C identifier (in lower and upper
   case), which must not contain underscores, for linking with Fortran. */
#define FC_FUNC(name,NAME) name ## _

/* As FC_FUNC, but for C identifiers containing underscores. */
#define FC_FUNC_(name,NAME) name ## _

/* Define to 1 if you have the `clock_gettime' function. */
#define HAVE_CLOCK_GETTIME 1

/* compile the code with debugging options */
/* #undef HAVE_DEBUG */

/* Flush(6) can be used safely in fortran */
#define HAVE_FC_FLUSH 1

/* get_command_argument() can be used safely in Fortran */
#define HAVE_FC_GET_COMMAND_ARGUMENT 1

/* If set, we can use gdbus */
/* #undef HAVE_GDBUS */

/* If set, we can call glib.h */
/* #undef HAVE_GLIB */

/* Define to 1 if you have the <inttypes.h> header file. */
/* #undef HAVE_INTTYPES_H */

/* use libABINIT in BigDFT. */
#define HAVE_LIBABINIT 1

/* Define to 1 if you have the `rt' library (-lrt). */
#define HAVE_LIBRT 1

/* use S_GPU in BigDFT. */
/* #undef HAVE_LIBSGPU */

/* use libXC in BigDFT. */
#define HAVE_LIBXC 1

/* libarchive is linkable. */
/* #undef HAVE_LIB_ARCHIVE */

/* Define to 1 if you have the <memory.h> header file. */
/* #undef HAVE_MEMORY_H */

/* use MPI2 capabilities. */
#define HAVE_MPI2 1

/* use MPI3 capabilities (like MPI_IALLREDUCE and MPI_IALLTOALLV). */
#define HAVE_MPI3 1

/* use MPI_INIT_THREAD */
#define HAVE_MPI_INIT_THREAD 1

/* Define to 1 if you have the <stdint.h> header file. */
/* #undef HAVE_STDINT_H */

/* Define to 1 if you have the <stdlib.h> header file. */
/* #undef HAVE_STDLIB_H */

/* Define to 1 if you have the <strings.h> header file. */
/* #undef HAVE_STRINGS_H */

/* Define to 1 if you have the <string.h> header file. */
/* #undef HAVE_STRING_H */

/* Define to 1 if you have the `strndup' function. */
#define HAVE_STRNDUP 1

/* Define to 1 if you have the <sys/stat.h> header file. */
/* #undef HAVE_SYS_STAT_H */

/* Define to 1 if you have the <sys/types.h> header file. */
/* #undef HAVE_SYS_TYPES_H */

/* Define to 1 if you have the <time.h> header file. */
#define HAVE_TIME_H 1

/* Define to 1 if you have the <unistd.h> header file. */
/* #undef HAVE_UNISTD_H */

/* If set, we can call yaml.h */
#define HAVE_YAML /**/

/* Name of package */
#define PACKAGE "bigdft"

/* Define to the address where bug reports for this package should be sent. */
#define PACKAGE_BUGREPORT "Damien.Caliste@cea.fr"

/* Define to the full name of this package. */
#define PACKAGE_NAME "BigDFT - DFT over wavelets"

/* Define to the full name and version of this package. */
#define PACKAGE_STRING "BigDFT - DFT over wavelets 1.7.6"

/* Define to the one symbol short name of this package. */
#define PACKAGE_TARNAME "bigdft"

/* Define to the home page for this package. */
#define PACKAGE_URL ""

/* Define to the version of this package. */
#define PACKAGE_VERSION "1.7.6"

/* Define to 1 if you have the ANSI C header files. */
/* #undef STDC_HEADERS */

/* Version number of package */
#define VERSION "1.7.6"
