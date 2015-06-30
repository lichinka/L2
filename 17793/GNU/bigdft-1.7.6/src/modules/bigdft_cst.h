/** @file
 * Bindings for the BigDFT package
 * @author
 * Copyright (C) 2013-2013 BigDFT group
 * This file is distributed under the terms of the
 * GNU General Public License, see ~/COPYING file
 * or http://www.gnu.org/copyleft/gpl.txt .
 * For the list of contributors, see ~/AUTHORS
**/


#ifndef BIGDFT_CST_H
#define BIGDFT_CST_H

/* GLib support. */
/*
#include <glib.h>
#include <glib-object.h>
*/
/* No GLib support, use same conventions. */

#include <stdlib.h>
#define TRUE 1
#define FALSE 0
#define gboolean int
#define g_malloc(A) malloc(A)
#define g_malloc0(A) malloc(A)
#define g_free(A)   free(A)
#define gint int
#define guint unsigned int
#define gchar char
#define gpointer void*
#define GQuark int
typedef struct _GArray {gchar *data; guint len;} GArray;
#define GType  int
#define g_array_index(A, T, I) (((T*)(A->data))[I])
GArray* g_array_sized_new(gboolean zero, gboolean nullify, guint ele_size, guint n_ele);
#define g_array_set_size(A, N) A->len = N
#define g_array_unref(A) free(A->data)
#define G_BEGIN_DECLS
#define G_END_DECLS
typedef struct _GObject {guint ref_count;} GObject;
#define G_OBJECT(O) ((GObject*)O)
#define g_object_ref(O) {O->ref_count += 1;}
#define g_object_unref(O) {O->ref_count -= 1;}
#define g_strdup(S) strdup(S)
#define g_strndup(S,N) strndup(S,N)


#define BIGDFT_STRING_VERSION "1.7.6"
#define BIGDFT_MAJOR_VERSION 1
#define BIGDFT_MINOR_VERSION 7

#define F90_1D_POINTER_SHIFT 0
#define F90_1D_POINTER_SIZE  6

#define F90_2D_POINTER_SHIFT 0
#define F90_2D_POINTER_SIZE  9

#define F90_3D_POINTER_SHIFT 0
#define F90_3D_POINTER_SIZE  12

#define F90_4D_POINTER_SHIFT 0
#define F90_4D_POINTER_SIZE  15

#define F90_5D_POINTER_SHIFT 0
#define F90_5D_POINTER_SIZE  18

#undef _BIGDFT_BUILD_FULL_BINDINGS_
/*
#define _BIGDFT_BUILD_FULL_BINDINGS_
*/

/* Internal types for Fortran datatypes. */
/* Basic types, used for minimal bindings only. */
#define F_TYPE(T) (T.add)
#define F_DEFINE_TYPE(T) typedef void f90_ ## T;                                  \
 typedef struct {f90_ ## T *add; char buf[64];} f90_ ## T ## _pointer

F_DEFINE_TYPE(dictionary);
F_DEFINE_TYPE(memory_estimation);
F_DEFINE_TYPE(atoms_data);
F_DEFINE_TYPE(atomic_structure);
F_DEFINE_TYPE(symmetry_data);
F_DEFINE_TYPE(input_variables);
F_DEFINE_TYPE(restart_objects);
F_DEFINE_TYPE(run_objects);
F_DEFINE_TYPE(DFT_global_output);
F_DEFINE_TYPE(DFT_PSP_projectors);
F_DEFINE_TYPE(energy_terms);
F_DEFINE_TYPE(run_image);
F_DEFINE_TYPE(NEB_data);
F_DEFINE_TYPE(system_fragment);
F_DEFINE_TYPE(comms_cubic);
/* Advanced types, used for full bindings. */
F_DEFINE_TYPE(xc_info);
F_DEFINE_TYPE(communications_arrays);
F_DEFINE_TYPE(coulomb_operator);
F_DEFINE_TYPE(denspot_distribution);
F_DEFINE_TYPE(DFT_local_fields);
F_DEFINE_TYPE(DFT_optimization_loop);
F_DEFINE_TYPE(DFT_wavefunction);
F_DEFINE_TYPE(GPU_pointers);
F_DEFINE_TYPE(grid_dimensions);
F_DEFINE_TYPE(local_zone_descriptors);
F_DEFINE_TYPE(locreg_descriptors);
F_DEFINE_TYPE(nonlocal_psp_descriptors);
F_DEFINE_TYPE(orbitals_data);
F_DEFINE_TYPE(rho_descriptors);
F_DEFINE_TYPE(rholoc_objects);
F_DEFINE_TYPE(wavefunctions_descriptors);
F_DEFINE_TYPE(gaussian_basis);
F_DEFINE_TYPE(cdft_data);

/***************************/
/* Generic pointer arrays. */
/***************************/
typedef struct _f90_pointer_double f90_pointer_double;
struct _f90_pointer_double
{
#if F90_1D_POINTER_SHIFT > 0
  void *shift[F90_1D_POINTER_SHIFT];
#endif
  double *data;
#if F90_1D_POINTER_SIZE - 1 - F90_1D_POINTER_SHIFT > 0
  void *info[F90_1D_POINTER_SIZE - 1 - F90_1D_POINTER_SHIFT];
#endif
};
typedef struct _f90_pointer_double_2D f90_pointer_double_2D;
struct _f90_pointer_double_2D
{
#if F90_2D_POINTER_SHIFT > 0
  void *shift[F90_2D_POINTER_SHIFT];
#endif
  double *data;
#if F90_2D_POINTER_SIZE - 1 - F90_2D_POINTER_SHIFT > 0
  void *info[F90_2D_POINTER_SIZE - 1 - F90_2D_POINTER_SHIFT];
#endif
};
typedef struct _f90_pointer_double_3D f90_pointer_double_3D;
struct _f90_pointer_double_3D
{
#if F90_3D_POINTER_SHIFT > 0
  void *shift[F90_3D_POINTER_SHIFT];
#endif
  double *data;
#if F90_3D_POINTER_SIZE - 1 - F90_3D_POINTER_SHIFT > 0
  void *info[F90_3D_POINTER_SIZE - 1 - F90_3D_POINTER_SHIFT];
#endif
};
typedef struct _f90_pointer_double_4D f90_pointer_double_4D;
struct _f90_pointer_double_4D
{
#if F90_4D_POINTER_SHIFT > 0
  void *shift[F90_4D_POINTER_SHIFT];
#endif
  double *data;
#if F90_4D_POINTER_SIZE - 1 - F90_4D_POINTER_SHIFT > 0
  void *info[F90_4D_POINTER_SIZE - 1 - F90_4D_POINTER_SHIFT];
#endif
};
typedef struct _f90_pointer_double_5D f90_pointer_double_5D;
struct _f90_pointer_double_5D
{
#if F90_5D_POINTER_SHIFT > 0
  void *shift[F90_5D_POINTER_SHIFT];
#endif
  double *data;
#if F90_5D_POINTER_SIZE - 1 - F90_5D_POINTER_SHIFT > 0
  void *info[F90_5D_POINTER_SIZE - 1 - F90_5D_POINTER_SHIFT];
#endif
};
typedef struct _f90_pointer_int f90_pointer_int;
struct _f90_pointer_int 
{
#if F90_1D_POINTER_SHIFT > 0
  void *shift[F90_1D_POINTER_SHIFT];
#endif
  int *data;
#if F90_1D_POINTER_SIZE - 1 - F90_1D_POINTER_SHIFT > 0
  void *info[F90_1D_POINTER_SIZE - 1 - F90_1D_POINTER_SHIFT];
#endif
};
typedef struct _f90_pointer_int_2D f90_pointer_int_2D;
struct _f90_pointer_int_2D
{
#if F90_2D_POINTER_SHIFT > 0
  void *shift[F90_2D_POINTER_SHIFT];
#endif
  int *data;
#if F90_2D_POINTER_SIZE - 1 - F90_2D_POINTER_SHIFT > 0
  void *info[F90_2D_POINTER_SIZE - 1 - F90_2D_POINTER_SHIFT];
#endif
};

#endif
