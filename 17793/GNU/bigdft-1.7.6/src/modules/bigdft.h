/** @file 
     Header for the public BigDFT API.
    @author
     Copyright (C) 2011-2013 BigDFT group (DC)
     This file is distributed under the terms of the
     GNU General Public License, see ~/COPYING file
     or http://www.gnu.org/copyleft/gpl.txt .
     For the list of contributors, see ~/AUTHORS 
*/


#ifndef BIGDFT_H
#define BIGDFT_H

#include <bigdft_cst.h>

G_BEGIN_DECLS


/*****************************************************/
/* Basics definitions with possibly no GLib support. */
/*****************************************************/
int bigdft_lib_init(guint *mpi_iproc, guint *mpi_nproc, guint *mpi_igroup, guint *mpi_ngroup,
                guint mpi_groupsize);
int bigdft_mpi_set_distribution(guint *mpi_iproc, guint *mpi_nproc,
                                guint *mpi_igroup, guint *mpi_ngroup,
                                guint mpi_groupsize);
void bigdft_mpi_force_group(guint igroup, guint ngroup);
int bigdft_lib_finalize();
guint bigdft_get_count(GObject *obj);

/******************************/
/* BigDFT_Dict data structure */
/******************************/
#ifdef GLIB_MAJOR_VERSION
#define BIGDFT_DICT_TYPE    (bigdft_dict_get_type())
#define BIGDFT_DICT(obj)                                               \
  (G_TYPE_CHECK_INSTANCE_CAST(obj, BIGDFT_DICT_TYPE, BigDFT_Dict))
#define BIGDFT_DICT_CLASS(klass)                                       \
  (G_TYPE_CHECK_CLASS_CAST(klass, BIGDFT_DICT_TYPE, BigDFT_DictClass))
#define BIGDFT_DICT_GET_CLASS(obj)                                     \
  (G_TYPE_INSTANCE_GET_CLASS(obj, BIGDFT_DICT_TYPE, BigDFT_DictClass))
#define BIGDFT_IS_CLASS_DICT(klass)                    \
  (G_TYPE_CHECK_CLASS_TYPE(klass, BIGDFT_DICT_TYPE))
#define BIGDFT_IS_TYPE_DICT(obj)                       \
  (G_TYPE_CHECK_INSTANCE_TYPE(obj, BIGDFT_DICT_TYPE))

typedef struct _BigDFT_DictClass BigDFT_DictClass;
struct _BigDFT_DictClass
{
  GObjectClass parent;
};
GType bigdft_dict_get_type(void);
#else
#define BIGDFT_DICT_TYPE    (999)
#define BIGDFT_DICT(obj)    ((BigDFT_Dict*)obj)
#endif
typedef struct _BigDFT_Dict BigDFT_Dict;
struct _BigDFT_Dict
{
  /* Object management. */
  GObject parent;
  gboolean dispose_has_run;

  /* Private. */
  f90_dictionary_pointer current;
  f90_dictionary_pointer root;
};
typedef struct _BigDFT_DictIter BigDFT_DictIter;
struct _BigDFT_DictIter
{
  BigDFT_Dict *dict;
  f90_dictionary_pointer pointer;
};
BigDFT_Dict *bigdft_dict_new     (BigDFT_DictIter *root);
BigDFT_Dict *bigdft_dict_new_from_yaml(const gchar *buf, BigDFT_DictIter *root);
void bigdft_dict_get_current     (BigDFT_Dict *dict, BigDFT_DictIter *iter);
gboolean bigdft_dict_move_to     (BigDFT_Dict *dict, BigDFT_DictIter *iter);
gboolean bigdft_dict_move_to_key (BigDFT_Dict *dict, const gchar *key,
                                  BigDFT_DictIter *iter);
gboolean bigdft_dict_move_to_item(BigDFT_Dict *dict, guint id, BigDFT_DictIter *iter);
gboolean bigdft_dict_iter        (BigDFT_Dict *dict, BigDFT_DictIter *iter);
gboolean bigdft_dict_next        (BigDFT_Dict *dict, BigDFT_DictIter *iter);
void  bigdft_dict_insert         (BigDFT_Dict *dict, const gchar *key,
                                  BigDFT_DictIter *iter);
void  bigdft_dict_append         (BigDFT_Dict *dict, BigDFT_DictIter *iter);
void  bigdft_dict_set            (BigDFT_Dict *dict, const gchar *id, const gchar *value);
void  bigdft_dict_set_array      (BigDFT_Dict *dict, const gchar *id, const gchar **value);
void  bigdft_dict_set_dict       (BigDFT_Dict *dict, const gchar *id, const BigDFT_Dict *value);
gboolean bigdft_dict_pop         (BigDFT_Dict *dict, const gchar *key);
gchar* bigdft_dict_key           (BigDFT_Dict *dict);
gchar* bigdft_dict_value         (BigDFT_Dict *dict);
guint bigdft_dict_len            (BigDFT_Dict *dict);
void  bigdft_dict_unref          (BigDFT_Dict *dict);
void  bigdft_dict_dump           (BigDFT_Dict *dict, gint unit);
void  bigdft_dict_dump_to_file   (BigDFT_Dict *dict, const gchar *filename);
/*********************************/

/********************************/
/* BigDFT_Atoms data structure. */
/********************************/
#ifdef GLIB_MAJOR_VERSION
#define BIGDFT_ATOMS_TYPE    (bigdft_atoms_get_type())
#define BIGDFT_ATOMS(obj)                                               \
  (G_TYPE_CHECK_INSTANCE_CAST(obj, BIGDFT_ATOMS_TYPE, BigDFT_Atoms))
#define BIGDFT_ATOMS_CLASS(klass)                                       \
  (G_TYPE_CHECK_CLASS_CAST(klass, BIGDFT_ATOMS_TYPE, BigDFT_AtomsClass))
#define BIGDFT_ATOMS_GET_CLASS(obj)                                     \
  (G_TYPE_INSTANCE_GET_CLASS(obj, BIGDFT_ATOMS_TYPE, BigDFT_AtomsClass))
#define BIGDFT_IS_CLASS_ATOMS(klass)                    \
  (G_TYPE_CHECK_CLASS_TYPE(klass, BIGDFT_ATOMS_TYPE))
#define BIGDFT_IS_TYPE_ATOMS(obj)                       \
  (G_TYPE_CHECK_INSTANCE_TYPE(obj, BIGDFT_ATOMS_TYPE))

typedef struct _BigDFT_AtomsClass BigDFT_AtomsClass;
struct _BigDFT_AtomsClass
{
  GObjectClass parent;
};
GType bigdft_atoms_get_type(void);
#else
#define BIGDFT_ATOMS_TYPE    (999)
#define BIGDFT_ATOMS(obj)    ((BigDFT_Atoms*)obj)
#endif
typedef struct _BigDFT_Atoms BigDFT_Atoms;
struct _BigDFT_Atoms
{
  /* Object management. */
  GObject parent;
  gboolean dispose_has_run;

  /* Bindings to values, obtained by copy. Update them with
     bigdft_atoms_sync(). */
  gchar geocode, format[6], units[21];
  guint  ntypes, nat, natsc;
  double alat[3];
  gchar **atomnames;
  gboolean donlcc;
  /* Bindings of pointer arrays, access is direct. */
  guint *iatype, *iasctype, *natpol, *nelpsp, *npspcode, *nzatom;
  int *nlcc_ngv, *nlcc_ngc, *ixcpsp, *ifrztyp;
  double *radii_cf, *amu, *aocc, *psppar, *nlccpar, *ig_nlccpar;

  /* Coordinates. */
  double *rxyz;
  double shift[3];

  /* Additional fields. */
  gchar *comment;
  double energy;

  /* Private. */
  f90_atomic_structure_pointer astruct;
  f90_atoms_data_pointer data;
  f90_symmetry_data_pointer sym;
};
/********************************/
BigDFT_Atoms* bigdft_atoms_new();
BigDFT_Atoms* bigdft_atoms_new_from_file     (const gchar *filename);
void          bigdft_atoms_unref             (BigDFT_Atoms *atoms);
void          bigdft_atoms_set_types         (BigDFT_Atoms *atoms, const gchar **names);
void          bigdft_atoms_set_n_atoms       (BigDFT_Atoms *atoms, guint nat);
void          bigdft_atoms_set_geometry      (BigDFT_Atoms *atoms, gchar geocode,
                                              double alat[3], const gchar *units);
gboolean      bigdft_atoms_set_structure_from_file(BigDFT_Atoms *atoms, const gchar *filename);
void          bigdft_atoms_set_psp           (BigDFT_Atoms *atoms, int ixc,
                                              guint nspin, const gchar *occup);
void          bigdft_atoms_set_symmetries    (BigDFT_Atoms *atoms, gboolean active,
                                              double tol, double elecfield[3], guint nspin);
void          bigdft_atoms_set_displacement  (BigDFT_Atoms *atoms, double randdis);
void          bigdft_atoms_copy_from_fortran (BigDFT_Atoms *atoms);
GArray*       bigdft_atoms_get_radii         (const BigDFT_Atoms *atoms, double crmult,
                                              double frmult, double projrad);
void          bigdft_atoms_set_default_file_format(BigDFT_Atoms *atoms, const gchar *format);
void          bigdft_atoms_write             (BigDFT_Atoms *atoms,
                                              const gchar *filename, const gchar *format);
gchar*        bigdft_atoms_get_extra_as_label(const BigDFT_Atoms *atoms, guint iat);
void          bigdft_atoms_merge_to_dict     (const BigDFT_Atoms *atoms,
                                              BigDFT_DictIter *iter);
/********************************/

/*********************************/
/* BigDFT_Inputs data structure. */
/*********************************/
typedef enum
  {
    BIGDFT_INPUTS_NONE   = 0,
    BIGDFT_INPUTS_DFT    = 1,
    BIGDFT_INPUTS_GEOPT  = 2,
    BIGDFT_INPUTS_PERF   = 4,
    BIGDFT_INPUTS_KPT    = 8,
    BIGDFT_INPUTS_MIX   = 16,
    BIGDFT_INPUTS_TDDFT = 32,
    BIGDFT_INPUTS_SIC   = 64,
    BIGDFT_INPUTS_FREQ = 128,
    BIGDFT_INPUTS_LIN  = 256,
    BIGDFT_INPUTS_UNPARSED = 65536
  } BigDFT_InputsFiles;
typedef enum
  {
    SMEARING_DIST_ERF   = 1,
    SMEARING_DIST_FERMI = 2,
    SMEARING_DIST_COLD1 = 3,
    SMEARING_DIST_COLD2 = 4,
    SMEARING_DIST_METPX = 5
  } BigDFT_Smearing;
typedef struct _BigDFT_Inputs BigDFT_Inputs;
struct _BigDFT_Inputs
{
  /* TODO: bindings to values... */
  gchar *dir_output, *writing_directory;
  gchar *run_name;
  
  /* DFT file variables. */
  int ixc, ncharge, nspin, mpol, ncong,
    dispersion, inputPsiId, output_wf_format, output_grid, ncongt, norbv, nvirt,
    nplot, disableSym;
  int last_run;
  guint itermax, nrepmax, idsx;
  double crmult, frmult, gnrm_cv, rbuf;
  double h[3], elecfield[3];

  /* MIX file variables. */
  int norbsempty;
  guint iscf, itrpmax;
  BigDFT_Smearing occopt;
  double alphamix, rpnrm_cv, gnrm_startmix, Tel, alphadiis;

  /* GEOPT file variables. */
  char geopt_approach[10];
  int ncount_cluster_x, history, ionmov;
  double frac_fluct, forcemax, randdis, betax, dtion;
  double strtarget[6];
  f90_pointer_double qmass;

  /* PERF file variables (partial). */
  guint linear;

  /* Private. */
  guint refCount;
  f90_input_variables_pointer data;
};
/*********************************/
#ifdef GLIB_MAJOR_VERSION
GType          bigdft_inputs_get_type         (void);
#endif
BigDFT_Inputs* bigdft_inputs_ref              (BigDFT_Inputs *in);
void           bigdft_inputs_unref            (BigDFT_Inputs *in);
void           bigdft_inputs_free             (BigDFT_Inputs *in);
void           bigdft_inputs_set              (BigDFT_Inputs *in, const gchar *level,
                                               const gchar *id, const gchar *value);
void           bigdft_inputs_set_array        (BigDFT_Inputs *in, const gchar *level,
                                               const gchar *id, const gchar **value);
/*********************************/

/*********************************/
/* BigDFT_Goutput data structure */
/*********************************/
typedef enum
  {
    BIGDFT_ENERGS_EKS
  } BigDFT_EnergsIds;

#ifdef GLIB_MAJOR_VERSION
#define BIGDFT_GOUTPUT_TYPE    (bigdft_goutput_get_type())
#define BIGDFT_GOUTPUT(obj)                                               \
  (G_TYPE_CHECK_INSTANCE_CAST(obj, BIGDFT_GOUTPUT_TYPE, BigDFT_Goutput))
typedef struct _BigDFT_GoutputClass BigDFT_GoutputClass;
struct _BigDFT_GoutputClass
{
  GObjectClass parent;
};
GType bigdft_goutput_get_type(void);
#else
#define BIGDFT_GOUTPUT_TYPE    (999)
#define BIGDFT_GOUTPUT(obj)    ((BigDFT_Goutput*)obj)
#endif
typedef struct _BigDFT_Goutput BigDFT_Goutput;
struct _BigDFT_Goutput
{
  GObject parent;
  gboolean dispose_has_run;

  /* Binded values. */
  double eh, exc, evxc, eion, edisp, ekin, epot, eproj, eexctX, ebs, eKS, trH, evsum, evsic;
  double etot;

  guint fdim;
  double *fxyz;
  double fnoise;
  double pressure;
  double strten[6];

  /* Private. */
  f90_DFT_global_output_pointer data;
  f90_energy_terms_pointer energs;
};
/********************************/
BigDFT_Goutput* bigdft_goutput_new        (guint nat);
void            bigdft_goutput_unref      (BigDFT_Goutput *energs);
void            bigdft_goutput_emit_energs(BigDFT_Goutput *energs, guint istep,
                                           BigDFT_EnergsIds kind);
/********************************/

/*********************************/
/* BigDFT_Memory data structure */
/*********************************/
/**
 * BigDFT_Memory:
 * @data: (skip):
 */
typedef struct _BigDFT_Memory BigDFT_Memory;
struct _BigDFT_Memory
{
  double submat;
  int ncomponents, norb, norbp;
  double oneorb, allpsi_mpi, psistorage;
  double projarr, grid, workarr;

  double kernel, density, psolver, ham;

  double peak;

  /* Private. */
  guint ref;
  f90_memory_estimation_pointer data;
};
BigDFT_Memory* bigdft_memory_ref(BigDFT_Memory *boxed);
void bigdft_memory_unref(BigDFT_Memory *boxed);
void bigdft_memory_dump(BigDFT_Memory *mem);
#ifdef GLIB_MAJOR_VERSION
GType bigdft_memory_get_type(void);
#endif
/*********************************/

/*********************************/
/* BigDFT_Run data structure */
/*********************************/
#ifdef GLIB_MAJOR_VERSION
#define BIGDFT_RUN_TYPE    (bigdft_run_get_type())
#define BIGDFT_RUN(obj)                                               \
  (G_TYPE_CHECK_INSTANCE_CAST(obj, BIGDFT_RUN_TYPE, BigDFT_Run))
typedef struct _BigDFT_RunClass BigDFT_RunClass;
struct _BigDFT_RunClass
{
  GObjectClass parent;
};
GType bigdft_run_get_type(void);
#else
#define BIGDFT_RUN_TYPE    (999)
#define BIGDFT_RUN(obj)    ((BigDFT_Run*)obj)
#endif
typedef struct _BigDFT_Run BigDFT_Run;
struct _BigDFT_Run
{
  GObject parent;
  gboolean dispose_has_run;

  BigDFT_Dict    *dict;
  BigDFT_Atoms   *atoms;
  BigDFT_Inputs  *inputs;

  /* Private. */
  f90_run_objects_pointer data;
};
/*********************************/
BigDFT_Run*     bigdft_run_new();
BigDFT_Run*     bigdft_run_new_from_files  (const gchar *radical, const gchar *posinp);
BigDFT_Run*     bigdft_run_new_from_dict   (BigDFT_Dict *dict);
void            bigdft_run_unref           (BigDFT_Run *run);
void            bigdft_run_update          (BigDFT_Run *run, BigDFT_Dict *dict);
gboolean        bigdft_run_dump            (BigDFT_Run *run, const gchar *filename,
                                            gboolean full);
BigDFT_Memory*  bigdft_run_memoryEstimation(BigDFT_Run *run, guint iproc, guint nproc);
BigDFT_Goutput* bigdft_run_calculate       (BigDFT_Run *run, guint iproc, guint nproc);
BigDFT_Dict*    bigdft_run_get_dict        (BigDFT_Run *run);
BigDFT_Atoms*   bigdft_run_get_atoms       (BigDFT_Run *run);
BigDFT_Inputs*  bigdft_run_get_inputs      (BigDFT_Run *run);
/*********************************/

/*******************************/
/* BigDFT_Image data structure */
/*******************************/
typedef enum
  {
    BIGDFT_IMAGE_STEEPEST_DESCENT,
    BIGDFT_IMAGE_FLETCHER_REEVES,
    BIGDFT_IMAGE_POLAK_RIBIERE,
    BIGDFT_IMAGE_QUICK_MIN,
    BIGDFT_IMAGE_DAMPED_VERLET,
    BIGDFT_IMAGE_SIM_ANNEALING
  } BigDFT_ImageAlgo;

#ifdef GLIB_MAJOR_VERSION
#define BIGDFT_IMAGE_TYPE    (bigdft_image_get_type())
#define BIGDFT_IMAGE(obj)                                               \
  (G_TYPE_CHECK_INSTANCE_CAST(obj, BIGDFT_IMAGE_TYPE, BigDFT_Image))
typedef struct _BigDFT_ImageClass BigDFT_ImageClass;
struct _BigDFT_ImageClass
{
  GObjectClass parent;
};
GType bigdft_image_get_type(void);
#else
#define BIGDFT_IMAGE_TYPE    (999)
#define BIGDFT_IMAGE(obj)    ((BigDFT_Image*)obj)
#endif
typedef struct _BigDFT_Image BigDFT_Image;
struct _BigDFT_Image
{
  GObject parent;
  gboolean dispose_has_image;

  /* Bind attributes. */
  BigDFT_Run *run;
  BigDFT_Goutput *outs;
  double error, F;
  guint id;

  /* Private. */
  f90_run_image_pointer data;
};
/*********************************/
/* BigDFT_Image* bigdft_image_new       (BigDFT_Atoms *atoms, BigDFT_Inputs *ins, */
/*                                       BigDFT_Restart *rst, BigDFT_ImageAlgo algo); */
void          bigdft_image_unref     (BigDFT_Image *image);
void          bigdft_image_update_pos(BigDFT_Image *image, guint iteration,
                                      const BigDFT_Image *imgm1, const BigDFT_Image *imgp1,
                                      double k_before, double k_after,
                                      gboolean climbing);
gboolean      bigdft_image_update_pos_from_file(BigDFT_Image *image, guint iteration,
                                                const gchar *filem1, const gchar *filep1,
                                                double k_before, double k_after, gboolean climbing);
void          bigdft_image_calculate (BigDFT_Image *image, guint iteration, guint id);
BigDFT_Run*   bigdft_image_get_run(BigDFT_Image *image);
BigDFT_Goutput* bigdft_image_get_outs(BigDFT_Image *image);

GArray* bigdft_image_set_distribute(gboolean *update, guint nimages, guint ngroup);
/*********************************/






/* Additional bindings (available only with GObject. */
#ifdef _BIGDFT_BUILD_FULL_BINDINGS_
typedef struct _BigDFT_Lzd BigDFT_Lzd;
typedef struct _BigDFT_Orbs BigDFT_Orbs;
typedef struct _BigDFT_Proj BigDFT_Proj;
typedef struct _BigDFT_LocalFields BigDFT_LocalFields;
typedef struct _BigDFT_OptLoop BigDFT_OptLoop;

typedef enum
  {
    BIGDFT_WF_FORMAT_NONE,
    BIGDFT_WF_FORMAT_PLAIN,
    BIGDFT_WF_FORMAT_BINARY,
    BIGDFT_WF_FORMAT_ETSF
  } BigDFT_WfFileFormats;

/*********************************/
/* BigDFT_Locreg data structure. */
/*********************************/
#ifdef GLIB_MAJOR_VERSION
#define BIGDFT_LOCREG_TYPE    (bigdft_locreg_get_type())
#define BIGDFT_LOCREG(obj)                                               \
  (G_TYPE_CHECK_INSTANCE_CAST(obj, BIGDFT_LOCREG_TYPE, BigDFT_Locreg))
typedef struct _BigDFT_LocregClass BigDFT_LocregClass;
struct _BigDFT_LocregClass
{
  GObjectClass parent;
};
GType bigdft_locreg_get_type(void);
#else
#define BIGDFT_LOCREG_TYPE    (999)
#define BIGDFT_LOCREG(obj)    ((BigDFT_Locreg*)obj)
#endif
typedef struct _BigDFT_Locreg BigDFT_Locreg;
/**
 * BigDFT_Locreg:
 * @radii: (element-type double):
 */
struct _BigDFT_Locreg
{
  BigDFT_Atoms parent;
#ifdef GLIB_MAJOR_VERSION
  gboolean dispose_has_run;
#endif

  /* Values that have been used to built this localisation region. */
  double h[3];
  GArray *radii;
  double crmult, frmult;

  /* Sizes of the boxes (taken from d). */
  guint n[3], ni[3], ns[3], nsi[3], nfl[3], nfu[3];
  guint norb;

  /* Values of the wfd descriptor. */
  guint nvctr_c, nvctr_f, nseg_c, nseg_f;
  guint *keyglob, *keygloc;
  guint *keyvloc, *keyvglob;

  /* Additionnal values. */
  double locrad, locregCenter[3];

  /* TODO: bindings to values... */

  /* Private. */
  _grid_dimensions *d;
  _wavefunctions_descriptors *wfd;
  _locreg_descriptors *data;
};
typedef enum
  {
    GRID_COARSE,
    GRID_FINE
  } BigDFT_Grid;

BigDFT_Locreg* bigdft_locreg_new           ();
void           bigdft_locreg_free          (BigDFT_Locreg *glr);
gboolean       bigdft_locreg_check         (const BigDFT_Locreg *glr);
void           bigdft_locreg_set_radii     (BigDFT_Locreg *glr, GArray *radii);
void           bigdft_locreg_set_size      (BigDFT_Locreg *glr, const double h[3],
                                            double crmult, double frmult);
void           bigdft_locreg_set_d_dims    (BigDFT_Locreg *lr, guint n[3], guint ni[3],
                                            guint ns[3], guint nsi[3], guint nfl[3], guint nfu[3]);
void           bigdft_locreg_set_wfd_dims  (BigDFT_Locreg *lr, guint nseg_c, guint nseg_f,
                                            guint nvctr_c, guint nvctr_f);
void           bigdft_locreg_init_d        (BigDFT_Locreg *glr);
void           bigdft_locreg_init_wfd      (BigDFT_Locreg *glr);
void           bigdft_locreg_init_bounds   (BigDFT_Locreg *lr);
gboolean*      bigdft_locreg_get_grid      (const BigDFT_Locreg *glr, BigDFT_Grid gridType);
double*        bigdft_locreg_convert_to_isf(const BigDFT_Locreg *glr, const double *psic);
void           bigdft_locreg_write_psi_compress(const BigDFT_Locreg *lr,
                                                guint unitwf, BigDFT_WfFileFormats format,
                                                gboolean linear, guint iorb, const guint n[3],
                                                const double *psic);
typedef struct _BigDFT_LocregIter BigDFT_LocregIter;
struct _BigDFT_LocregIter
{
  const BigDFT_Locreg *glr;
  guint nseg, iseg, grid[3];

  guint i3, i2, i1, i0;
  double x0, x1, y, z;
};
gboolean       bigdft_locreg_iter_new      (BigDFT_LocregIter *iter,
                                            const BigDFT_Locreg *glr,
                                            BigDFT_Grid gridType);
gboolean       bigdft_locreg_iter_next     (BigDFT_LocregIter *iter);

/*********************************/
/* BigDFT_Lzd data structure. */
/*********************************/
#ifdef GLIB_MAJOR_VERSION
#define BIGDFT_LZD_TYPE    (bigdft_lzd_get_type())
#define BIGDFT_LZD(obj)                                               \
  (G_TYPE_CHECK_INSTANCE_CAST(obj, BIGDFT_LZD_TYPE, BigDFT_Lzd))
typedef struct _BigDFT_LzdClass BigDFT_LzdClass;
struct _BigDFT_LzdClass
{
  GObjectClass parent;
};
GType bigdft_lzd_get_type(void);
#else
#define BIGDFT_LZD_TYPE    (999)
#define BIGDFT_LZD(obj)    ((BigDFT_Lzd*)obj)
#endif
struct _BigDFT_Lzd
{
  BigDFT_Locreg parent;
#ifdef GLIB_MAJOR_VERSION
  gboolean dispose_has_run;
#endif

  /* Bind of Llr array. */
  guint nlr;
  BigDFT_Locreg **Llr;

  /* Private. */
  _local_zone_descriptors *data;
};
BigDFT_Lzd* bigdft_lzd_new();
BigDFT_Lzd* bigdft_lzd_new_with_fortran (void *fortran_lzd);
BigDFT_Lzd* bigdft_lzd_new_from_fortran (void *fortran_lzd);
void        bigdft_lzd_free             (BigDFT_Lzd *lzd);
gboolean    bigdft_lzd_check            (const BigDFT_Lzd *lzd);
void        bigdft_lzd_emit_defined     (BigDFT_Lzd *lzd);
void        bigdft_lzd_init_d           (BigDFT_Lzd *lzd);
void        bigdft_lzd_set_n_locreg     (BigDFT_Lzd *lzd, guint nlr);
void        bigdft_lzd_set_irreductible_zone(BigDFT_Lzd *lzd, guint npsin);
void        bigdft_lzd_copy_from_fortran(BigDFT_Lzd *lzd, GArray *radii,
                                         double crmult, double frmult);
void        bigdft_lzd_define           (BigDFT_Lzd *lzd, guint type,
                                         BigDFT_Orbs *orbs, guint iproc, guint nproc);
gboolean    bigdft_lzd_iter_new         (const BigDFT_Lzd *lzd, BigDFT_LocregIter *iter,
                                         BigDFT_Grid gridType, guint ilr);
gboolean    bigdft_lzd_iter_next        (BigDFT_LocregIter *iter);


/*******************************/
/* BigDFT_Orbs data structure. */
/*******************************/
#ifdef GLIB_MAJOR_VERSION
#define BIGDFT_ORBS_TYPE    (bigdft_orbs_get_type())
#define BIGDFT_ORBS(obj)                                               \
  (G_TYPE_CHECK_INSTANCE_CAST(obj, BIGDFT_ORBS_TYPE, BigDFT_Orbs))
typedef struct _BigDFT_OrbsClass BigDFT_OrbsClass;
struct _BigDFT_OrbsClass
{
  GObjectClass parent;
};
GType bigdft_orbs_get_type(void);
#else
#define BIGDFT_ORBS_TYPE    (999)
#define BIGDFT_ORBS(obj)    ((BigDFT_Orbs*)obj)
#endif
struct _BigDFT_Orbs
{
#ifdef GLIB_MAJOR_VERSION
  GObject parent;
  gboolean dispose_has_run;
#endif

  /* TODO: bindings to values... */
  guint norb, norbp, norbu, norbd;
  guint nspin, nspinor, npsidim;
  guint nkpts, nkptsp;
  guint isorb, iskpts;

  double efermi, HLgap, eTS;

     /* integer, dimension(:), pointer :: iokpt,ikptproc */
     /* integer, dimension(:,:), pointer :: norb_par */
  double *eval, *occup;
  double *kwgts, *kpts;

  guint *inwhichlocreg, *onwhichmpi, *onwhichatom;

  /* Pointers on building objects. */
  const BigDFT_Inputs *in;

  /* Private. */
  gboolean linear, withder;
  _orbitals_data *data, *lorbs;
  _communications_arrays *comm;
};

BigDFT_Orbs* bigdft_orbs_new (gboolean linear);
void         bigdft_orbs_free(BigDFT_Orbs *orbs);
guint        bigdft_orbs_define(BigDFT_Orbs *orbs, const BigDFT_Locreg *glr,
                                const BigDFT_Inputs *in, guint iproc, guint nproc);
gboolean     bigdft_orbs_get_linear(const BigDFT_Orbs *orbs);

/*****************************/
/* BigDFT_Wf data structure. */
/*****************************/
#ifdef GLIB_MAJOR_VERSION
#define BIGDFT_WF_TYPE    (bigdft_wf_get_type())
#define BIGDFT_WF(obj)                                          \
  (G_TYPE_CHECK_INSTANCE_CAST(obj, BIGDFT_WF_TYPE, BigDFT_Wf))
typedef struct _BigDFT_WfClass BigDFT_WfClass;
struct _BigDFT_WfClass
{
  GObjectClass parent;
};
GType bigdft_wf_get_type(void);
#else
#define BIGDFT_WF_TYPE    (999)
#define BIGDFT_WF(obj)    ((BigDFT_Wf*)obj)
#endif
typedef struct _BigDFT_Wf BigDFT_Wf;
struct _BigDFT_Wf
{
  BigDFT_Orbs parent;
#ifdef GLIB_MAJOR_VERSION
  gboolean dispose_has_run;
#endif

  /* Accessors. */
  BigDFT_Lzd *lzd;
  f90_pointer_double *psi, *hpsi, *psit, *spsi;

  /* private. */
  int inputpsi;
  guint input_wf_format;
  _DFT_wavefunction *data;
  _local_zone_descriptors *data_lzd;
  void *diis;
};
typedef enum
  {
    BIGDFT_PSI,
    BIGDFT_HPSI
  } BigDFT_PsiId;
typedef enum
  {
    BIGDFT_SPIN_UP,
    BIGDFT_SPIN_DOWN
  } BigDFT_Spin;
typedef enum
  {
    BIGDFT_REAL,
    BIGDFT_IMAG,
    BIGDFT_PARTIAL_DENSITY
  } BigDFT_Spinor;

BigDFT_Wf* bigdft_wf_new (int inputPsiId);
BigDFT_Wf* bigdft_wf_new_from_fortran(void *obj, gboolean linear);
void       bigdft_wf_free(BigDFT_Wf *wf);
guint      bigdft_wf_define(BigDFT_Wf *wf, const BigDFT_Inputs *in, guint iproc, guint nproc);
void       bigdft_wf_init_linear_comm(BigDFT_Wf *wf, const BigDFT_LocalFields *denspot,
                                      const BigDFT_Inputs *in, guint iproc, guint nproc);
void       bigdft_wf_calculate_psi0(BigDFT_Wf *wf, BigDFT_LocalFields *denspot,
                                    BigDFT_Proj *proj, BigDFT_Goutput *energs,
                                    guint iproc, guint nproc);
guint      bigdft_wf_optimization_loop(BigDFT_Wf *wf, BigDFT_LocalFields *denspot,
                                       BigDFT_Proj *proj, BigDFT_Goutput *energs,
                                       BigDFT_OptLoop *params, guint iproc, guint nproc);
void       bigdft_wf_post_treatments(BigDFT_Wf *wf, BigDFT_LocalFields *denspot,
                                     BigDFT_Proj *proj, BigDFT_Goutput *energs,
                                     guint iproc, guint nproc);
BigDFT_Locreg* bigdft_wf_get_locreg(const BigDFT_Wf *wf, guint ikpt, guint iorb,
                                    BigDFT_Spin ispin, guint iproc);
const double* bigdft_wf_get_compress(const BigDFT_Wf *wf, BigDFT_PsiId ipsi,
                                     guint ikpt, guint iorb, BigDFT_Spin ispin, BigDFT_Spinor ispinor,
                                     guint *psiSize, guint iproc);
const double* bigdft_wf_get_psi_compress(const BigDFT_Wf *wf, guint ikpt, guint iorb,
                                         BigDFT_Spin ispin, BigDFT_Spinor ispinor,
                                         guint *psiSize, guint iproc);
const double* bigdft_wf_get_hpsi_compress(const BigDFT_Wf *wf, guint ikpt, guint iorb,
                                          BigDFT_Spin ispin, BigDFT_Spinor ispinor,
                                          guint *psiSize, guint iproc);
gboolean   bigdft_wf_copy_compress(const BigDFT_Wf *wf, BigDFT_PsiId ipsi,
                                   guint ikpt, guint iorb, BigDFT_Spin ispin, BigDFT_Spinor ispinor,
                                   guint iproc, double *psic, guint psiAlloc);
gboolean   bigdft_wf_copy_psi_compress(const BigDFT_Wf *wf, guint ikpt, guint iorb,
                                       BigDFT_Spin ispin, BigDFT_Spinor ispinor,
                                       guint iproc, double *psic, guint psiSize);
gboolean   bigdft_wf_copy_hpsi_compress(const BigDFT_Wf *wf, guint ikpt, guint iorb,
                                        BigDFT_Spin ispin, BigDFT_Spinor ispinor,
                                        guint iproc, double *psic, guint psiAlloc);
double*    bigdft_wf_convert_to_isf(const BigDFT_Wf *wf, guint ikpt, guint iorb,
                                    BigDFT_Spin ispin, BigDFT_Spinor ispinor, guint iproc);
void       bigdft_wf_write_psi_compress(const BigDFT_Wf *wf, const gchar *filename,
                                        BigDFT_WfFileFormats format, const double *psic,
                                        guint ikpt, guint iorb, BigDFT_Spin ispin, guint psiSize);
void       bigdft_wf_optimization(BigDFT_Wf *wf, BigDFT_Proj *proj,
                                  BigDFT_LocalFields *denspot, BigDFT_Goutput *energs,
                                  BigDFT_OptLoop *params, const BigDFT_Inputs *in,
                                  gboolean threaded, guint iproc, guint nproc);
#ifdef GLIB_MAJOR_VERSION
void       bigdft_wf_emit_one_wave(BigDFT_Wf *wf, guint iter, GArray *psic, GQuark quark,
                                   BigDFT_PsiId ipsi, guint ikpt, guint iorb, guint ispin);
#endif

/*******************************/
/* BigDFT_Proj data structure. */
/*******************************/
#ifdef GLIB_MAJOR_VERSION
#define BIGDFT_PROJ_TYPE    (bigdft_proj_get_type())
#define BIGDFT_PROJ(obj)                                               \
  (G_TYPE_CHECK_INSTANCE_CAST(obj, BIGDFT_PROJ_TYPE, BigDFT_Proj))
typedef struct _BigDFT_ProjClass BigDFT_ProjClass;
struct _BigDFT_ProjClass
{
  GObjectClass parent;
};
GType bigdft_proj_get_type(void);
#else
#define BIGDFT_PROJ_TYPE    (999)
#define BIGDFT_PROJ(obj)    ((BigDFT_Proj*)obj)
#endif
struct _BigDFT_Proj
{
#ifdef GLIB_MAJOR_VERSION
  GObject parent;
  gboolean dispose_has_run;
#endif

  /* TODO: bindings to values... */
  guint nproj, nprojel;

  /* Additional pointers. */
  f90_pointer_double proj;

  /* Private. */
  _nonlocal_psp_descriptors *nlpspd;
};

BigDFT_Proj* bigdft_proj_new (const BigDFT_Locreg *glr, const BigDFT_Orbs *orbs,
                              double frmult);
void         bigdft_proj_free(BigDFT_Proj *proj);

/**********************************/
/* BigDFT_DensPot data structure. */
/**********************************/
typedef enum
  {
    BIGDFT_RHO_IS_EMPTY              = -1980,
    BIGDFT_RHO_IS_ELECTRONIC_DENSITY = -1979,
    BIGDFT_RHO_IS_CHARGE_DENSITY     = -1978,
    BIGDFT_RHO_IS_KS_POTENTIAL       = -1977,
    BIGDFT_RHO_IS_HARTREE_POTENTIAL  = -1976
  } BigDFT_RhoIs;
typedef enum
  {
    BIGDFT_DENSPOT_DENSITY,
    BIGDFT_DENSPOT_V_EXT
  } BigDFT_DensPotIds;

#ifdef GLIB_MAJOR_VERSION
#define BIGDFT_LOCALFIELDS_TYPE    (bigdft_localfields_get_type())
#define BIGDFT_LOCALFIELDS(obj)                                               \
  (G_TYPE_CHECK_INSTANCE_CAST(obj, BIGDFT_LOCALFIELDS_TYPE, BigDFT_LocalFields))
typedef struct _BigDFT_LocalFieldsClass BigDFT_LocalFieldsClass;
struct _BigDFT_LocalFieldsClass
{
  GObjectClass parent;
};
GType bigdft_localfields_get_type(void);
#else
#define BIGDFT_LOCALFIELDS_TYPE    (999)
#define BIGDFT_LOCALFIELDS(obj)    ((BigDFT_LocalFields*)obj)
#endif
struct _BigDFT_LocalFields
{
#ifdef GLIB_MAJOR_VERSION
  GObject parent;
  gboolean dispose_has_run;
#endif
  /* bindings to values... */
  BigDFT_RhoIs rhov_is;
  double psoffset;
  double h[3];
  guint ni[3];

  double eion, edisp, ewaldstr[6], xcstr[6];
  f90_pointer_double_2D fion, fdisp;

  /* Additional pointers. */
  double *rhov, *v_ext, *v_xc;
  /* TODO, see when these are associated. */
  /* double *rho_full, *pot_full, *rho_psi, *rho_c, *vloc_ks, *f_xc; */

  /* Private. */
  void *pkernel, *pkernelseq;
  _rho_descriptors *rhod;
  _denspot_distribution *dpbox;
  _DFT_local_fields *data;
};

BigDFT_LocalFields* bigdft_localfields_new (const BigDFT_Lzd *lzd,
                                            const BigDFT_Inputs *in,
                                            guint iproc, guint nproc);
BigDFT_LocalFields* bigdft_localfields_new_from_fortran(void *obj);
void                bigdft_localfields_free(BigDFT_LocalFields *denspotd);
void bigdft_localfields_create_poisson_kernels(BigDFT_LocalFields *localfields);
void bigdft_localfields_create_effective_ionic_pot(BigDFT_LocalFields *denspot,
                                                   const BigDFT_Lzd *lzd,
                                                   const BigDFT_Inputs *in,
                                                   guint iproc, guint nproc);
void bigdft_localfields_emit_rhov(BigDFT_LocalFields *denspot, guint istep);
void bigdft_localfields_emit_v_ext(BigDFT_LocalFields *denspot);
GArray* bigdft_localfields_get_field(BigDFT_LocalFields *denspot, BigDFT_DensPotIds id);


/*********************************/
/* BigDFT_OptLoop data structure */
/*********************************/
typedef enum
  {
    BIGDFT_OPTLOOP_ITER_HAMILTONIAN,
    BIGDFT_OPTLOOP_ITER_SUBSPACE,
    BIGDFT_OPTLOOP_ITER_WAVEFUNCTIONS,
    BIGDFT_OPTLOOP_DONE_HAMILTONIAN,
    BIGDFT_OPTLOOP_DONE_SUBSPACE,
    BIGDFT_OPTLOOP_DONE_WAVEFUNCTIONS
  } BigDFT_OptLoopIds;
#ifdef GLIB_MAJOR_VERSION
#define BIGDFT_OPTLOOP_TYPE    (bigdft_optloop_get_type())
#define BIGDFT_OPTLOOP(obj)                                               \
  (G_TYPE_CHECK_INSTANCE_CAST(obj, BIGDFT_OPTLOOP_TYPE, BigDFT_OptLoop))
typedef struct _BigDFT_OptLoopClass BigDFT_OptLoopClass;
struct _BigDFT_OptLoopClass
{
  GObjectClass parent;
};
GType bigdft_optloop_get_type(void);
#else
#define BIGDFT_OPTLOOP_TYPE    (999)
#define BIGDFT_OPTLOOP(obj)    ((BigDFT_OptLoop*)obj)
#endif
struct _BigDFT_OptLoop
{
#ifdef GLIB_MAJOR_VERSION
  GObject parent;
  gboolean dispose_has_run;
#endif

  /* Binded values. */
  double gnrm_cv, rpnrm_cv, gnrm_startmix;
  double gnrm, rpnrm;
  guint itrpmax, nrepmax, itermax;
  guint itrp, itrep, iter;
  int iscf, infocode;

  /* Private. */
  _DFT_optimization_loop *data;
};
BigDFT_OptLoop* bigdft_optloop_new();
BigDFT_OptLoop* bigdft_optloop_new_from_fortran(void *obj);
void            bigdft_optloop_free(BigDFT_OptLoop *optloop);
void            bigdft_optloop_copy_from_fortran(BigDFT_OptLoop *optloop);
void            bigdft_optloop_sync_to_fortran(BigDFT_OptLoop *optloop);
void            bigdft_optloop_emit(BigDFT_OptLoop *optloop, BigDFT_OptLoopIds kind,
                                    BigDFT_Goutput *energs);

/******************/
/* Miscellaneous. */
/******************/
typedef enum
  {
    BIGDFT_SIGNALS_NONE,
    BIGDFT_SIGNALS_DBUS,
    BIGDFT_SIGNALS_INET
  } BigDFT_SignalModes;
#ifdef GLIB_MAJOR_VERSION
#include <gio/gio.h>

typedef struct _BigDFT_SignalsHandler BigDFT_SignalsClient;

BigDFT_SignalsClient* bigdft_signals_client_new(const gchar *hostname,
                                                GCancellable *cancellable, GError **error);
BigDFT_SignalsClient* bigdft_signals_client_ref(BigDFT_SignalsClient *client);
void bigdft_signals_client_unref(BigDFT_SignalsClient *client);
GType bigdft_signals_client_get_type(void);
GSource* bigdft_signals_client_create_source(BigDFT_SignalsClient *client, BigDFT_Goutput *energs,
                                             BigDFT_Wf *wf, BigDFT_LocalFields *denspot,
                                             BigDFT_OptLoop *optloop, GCancellable *cancellable,
                                             GDestroyNotify destroy, gpointer data);
void bigdft_signals_client_create_thread(BigDFT_SignalsClient *client, BigDFT_Goutput *energs,
                                         BigDFT_Wf *wf, BigDFT_LocalFields *denspot,
                                         BigDFT_OptLoop *optloop, GCancellable *cancellable,
                                         GDestroyNotify destroy, gpointer user_data);
void bigdft_signals_client_set_block_run(BigDFT_SignalsClient *client, gboolean status);
gboolean bigdft_signals_client_get_block_run(BigDFT_SignalsClient *client);
void bigdft_signals_client_free(BigDFT_SignalsClient *client);
#endif

double bigdft_memory_get_peak(guint nproc, const BigDFT_Locreg *lr, const BigDFT_Inputs *in,
                              const BigDFT_Orbs *orbs, const BigDFT_Proj *proj);

f90_pointer_double_4D* bigdft_read_wave_to_isf(const gchar *filename, int iorbp,
                                               double h[3], int n[3], int *nspinor);
void bigdft_free_wave_to_isf(f90_pointer_double_4D *psiscf);
gboolean bigdft_read_wave_descr(const gchar *filename, int *norbu,
                                int *norbd, int *nkpt, int *nspinor,
                                int *iorb, int *ispin, int *ikpt, int *ispinor);
#endif
#endif
G_END_DECLS

