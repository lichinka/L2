#include <config.h>

#ifdef HAVE_GLIB
#include <glib-object.h>
#include <gio/gio.h>
#endif

#include "bigdft.h"
#include "bindings.h"
#include "bindings_api.h"

#include <string.h>
#include <stdlib.h>
#include <stdio.h>


static void bigdft_orbs_dispose(GObject *orbs);
static void bigdft_orbs_finalize(GObject *orbs);

#ifdef HAVE_GLIB
enum
  {
    ORBS_PROP_0,
    LINEAR_PROP,
    DERIVATIVES_PROP
  };
static void bigdft_orbs_get_property(GObject* obj, guint property_id,
                                     GValue *value, GParamSpec *pspec);
static void bigdft_orbs_set_property(GObject* obj, guint property_id,
                                     const GValue *value, GParamSpec *pspec);

G_DEFINE_TYPE(BigDFT_Orbs, bigdft_orbs, G_TYPE_OBJECT)

static void bigdft_orbs_class_init(BigDFT_OrbsClass *klass)
{
  /* Connect the overloading methods. */
  G_OBJECT_CLASS(klass)->dispose      = bigdft_orbs_dispose;
  G_OBJECT_CLASS(klass)->finalize     = bigdft_orbs_finalize;
  G_OBJECT_CLASS(klass)->set_property = bigdft_orbs_set_property;
  G_OBJECT_CLASS(klass)->get_property = bigdft_orbs_get_property;

  g_object_class_install_property(G_OBJECT_CLASS(klass), LINEAR_PROP,
				  g_param_spec_boolean("linear", "Localised orbitals",
                                                       "Orbitals descriptors are for "
                                                       "the cubic or linear version",
                                                       FALSE,
                                                       G_PARAM_CONSTRUCT_ONLY |
                                                       G_PARAM_READWRITE));
}

static void bigdft_orbs_get_property(GObject* obj, guint property_id,
                                     GValue *value, GParamSpec *pspec)
{
  BigDFT_Orbs *self = BIGDFT_ORBS(obj);

  switch (property_id)
    {
    case LINEAR_PROP:
      g_value_set_boolean(value, self->linear);
      break;
    default:
      /* We don't have any other property... */
      G_OBJECT_WARN_INVALID_PROPERTY_ID(obj, property_id, pspec);
      break;
    }
}
static void bigdft_orbs_set_property(GObject* obj, guint property_id,
                                     const GValue *value, GParamSpec *pspec)
{
  BigDFT_Orbs *self = BIGDFT_ORBS(obj);

  switch (property_id)
    {
    case LINEAR_PROP:
      self->linear = g_value_get_boolean(value);
      if (self->linear)
        {
          FC_FUNC_(orbs_new, ORBS_NEW)(&self->lorbs);
          FC_FUNC_(orbs_init, ORBS_INIT)(self->lorbs);
        }
      break;
    default:
      /* We don't have any other property... */
      G_OBJECT_WARN_INVALID_PROPERTY_ID(obj, property_id, pspec);
      break;
    }
}
#endif

static void bigdft_orbs_init(BigDFT_Orbs *obj)
{
#ifdef HAVE_GLIB
  memset((void*)((char*)obj + sizeof(GObject)), 0, sizeof(BigDFT_Orbs) - sizeof(GObject));
#else
  memset(obj, 0, sizeof(BigDFT_Orbs));
#endif
}
static void bigdft_orbs_dispose(GObject *obj)
{
#ifdef HAVE_GLIB
  BigDFT_Orbs *orbs = BIGDFT_ORBS(obj);

  if (orbs->dispose_has_run)
    return;
  orbs->dispose_has_run = TRUE;

  if (orbs->data)
    FC_FUNC_(orbs_empty, ORBS_EMPTY)(orbs->data);
  if (orbs->comm)
    FC_FUNC_(orbs_comm_empty, ORBS_COMM_EMPTY)(orbs->comm);
  if (orbs->lorbs)
    FC_FUNC_(orbs_empty, ORBS_EMPTY)(orbs->lorbs);
  
  /* Chain up to the parent class */
  G_OBJECT_CLASS(bigdft_orbs_parent_class)->dispose(obj);
#endif
}
static void bigdft_orbs_finalize(GObject *obj)
{
  BigDFT_Orbs *orbs = BIGDFT_ORBS(obj);

  if (orbs->data)
    FC_FUNC_(orbs_free, ORBS_FREE)(&orbs->data);
  if (orbs->comm)
    FC_FUNC_(orbs_comm_free, ORBS_COMM_FREE)(&orbs->comm);
  if (orbs->lorbs)
    FC_FUNC_(orbs_free, ORBS_FREE)(&orbs->lorbs);

#ifdef HAVE_GLIB
  G_OBJECT_CLASS(bigdft_orbs_parent_class)->finalize(obj);
#endif
}

BigDFT_Orbs* bigdft_orbs_new(gboolean linear)
{
  BigDFT_Orbs *orbs;

#ifdef HAVE_GLIB
  orbs = BIGDFT_ORBS(g_object_new(BIGDFT_ORBS_TYPE, "linear", linear, NULL));
#else
  orbs = g_malloc(sizeof(BigDFT_Orbs));
  bigdft_orbs_init(orbs);
  orbs->linear = linear;
#endif

  FC_FUNC_(orbs_new, ORBS_NEW)(&orbs->data);
  FC_FUNC_(orbs_init, ORBS_INIT)(orbs->data);
  
  return orbs;
}
void bigdft_orbs_free(BigDFT_Orbs *orbs)
{
#ifdef HAVE_GLIB
  g_object_unref(G_OBJECT(orbs));
#else
  bigdft_orbs_finalize(orbs);
  g_free(orbs);
#endif
}
guint bigdft_orbs_define(BigDFT_Orbs *orbs, const BigDFT_Locreg *glr, const BigDFT_Inputs *in,
                         guint iproc, guint nproc)
{
  int verb = 0;
  gboolean nspinor = 1;

  orbs->in = in;
  FC_FUNC_(orbs_empty, ORBS_EMPTY)(orbs->data);
  FC_FUNC_(read_orbital_variables, READ_ORBITAL_VARIABLES)((int*)&iproc, (int*)&nproc,
                                                           &verb, in->data,
                                                           glr->parent.data, orbs->data);
  GET_ATTR_UINT(orbs, ORBS, inwhichlocreg, INWHICHLOCREG);
  GET_ATTR_UINT(orbs, ORBS, onwhichmpi,    ONWHICHMPI);
  GET_ATTR_UINT(orbs, ORBS, onwhichatom,   ONWHICHATOM);
  if (orbs->linear)
    {
      FC_FUNC_(orbs_empty, ORBS_EMPTY)(orbs->lorbs);
      FC_FUNC_(init_orbitals_data_for_linear, INIT_ORBITALS_DATA_FOR_LINEAR)
        ((int*)&iproc, (int*)&nproc, &nspinor, in->data, glr->parent.data,
         glr->parent.rxyz.data, orbs->lorbs);
      /* GET_ATTR_UINT(orbs, ORBS, inwhichlocreg, INWHICHLOCREG); */
      /* GET_ATTR_UINT(orbs, ORBS, onwhichmpi,    ONWHICHMPI); */
      /* GET_ATTR_UINT(orbs, ORBS, onwhichatom,   ONWHICHATOM); */
    }

  if (!orbs->comm)
    FC_FUNC_(orbs_comm_new, ORBS_COMM_NEW)(&orbs->comm);
  else
    FC_FUNC_(orbs_comm_empty, ORBS_COMM_EMPTY)(orbs->comm);
  FC_FUNC_(orbs_comm_init, ORBS_COMM_INIT)(orbs->comm, orbs->data, glr->data,
                                           (int*)&iproc, (int*)&nproc);

  FC_FUNC_(orbs_get_dimensions, ORBS_GET_DIMENSIONS)(orbs->data, (int*)&orbs->norb,
                                                     (int*)&orbs->norbp, (int*)&orbs->norbu,
                                                     (int*)&orbs->norbd, (int*)&orbs->nspin,
                                                     (int*)&orbs->nspinor, (int*)&orbs->npsidim,
                                                     (int*)&orbs->nkpts, (int*)&orbs->nkptsp,
                                                     (int*)&orbs->isorb, (int*)&orbs->iskpts);
  GET_ATTR_DBL   (orbs, ORBS, occup, OCCUP);
  GET_ATTR_DBL   (orbs, ORBS, kwgts, KWGTS);
  GET_ATTR_DBL_2D(orbs, ORBS, kpts,  KPTS);

  return 0;
}
gboolean bigdft_orbs_get_linear(const BigDFT_Orbs *orbs)
{
  return orbs->linear;
}
static gboolean _orbs_get_iorbp(const BigDFT_Orbs *orbs, guint ikpt, guint iorb,
                                BigDFT_Spin ispin, BigDFT_Spinor ispinor,
                                int *iorbp, int *isorb, int *jproc)
{
  guint ispinor_;

  if (ispin == BIGDFT_SPIN_DOWN && orbs->norbd == 0)
    return FALSE;
  if (ispinor == BIGDFT_IMAG && orbs->nspinor == 1)
    return FALSE;
  
  /* Get the shift to apply on wf->psi to get the right orbital. */
  ispinor_  = (ispinor != BIGDFT_PARTIAL_DENSITY)?ispinor:BIGDFT_REAL;
  ispinor_ += 1;
  ispin    += 1;
  FC_FUNC_(orbs_get_iorbp, ORBS_GET_IORBP)(orbs->data, iorbp, isorb, jproc,
                                           (int*)&ikpt, (int*)&iorb,
                                           (int*)&ispin, (int*)&ispinor_);
  if (iorbp < 0)
    return FALSE;

  return TRUE;
}

f90_pointer_double_4D* bigdft_read_wave_to_isf(const char *filename, int iorbp,
                                               double h[3], int n[3], int *nspinor)
{
  int ln, lstat;
  f90_pointer_double_4D *psiscf;

  psiscf = g_malloc(sizeof(f90_pointer_double_4D));
  F90_4D_POINTER_INIT(psiscf);
  
  ln = strlen(filename);
  FC_FUNC_(read_wave_to_isf, READ_WAVE_TO_ISF)
    (&lstat, filename, &ln, &iorbp, h, h + 1, h + 2, n, n + 1, n + 2, nspinor, psiscf, ln);
  if (!lstat)
    {
      g_free(psiscf);
      psiscf = (f90_pointer_double_4D*)0;
    }

  DBG_MEM(psiscf, f90_pointer_double_4D);

  return psiscf;
}
void bigdft_free_wave_to_isf(f90_pointer_double_4D *psiscf)
{
  FC_FUNC_(free_wave_to_isf, FREE_WAVE_TO_ISF)(psiscf);
  g_free(psiscf);
}

gboolean bigdft_read_wave_descr(const char *filename, int *norbu,
                                int *norbd, int *nkpt, int *nspinor,
                                int *iorb, int *ispin, int *ikpt, int *ispinor)
{
  int ln, lstat, norbu_, norbd_, nkpt_, nspinor_;
  int iorb_, ispin_, ikpt_, ispinor_;
  
  ln = strlen(filename);
  FC_FUNC_(read_wave_descr, READ_WAVE_DESCR)
    (&lstat, filename, &ln, &norbu_, &norbd_, &iorb_, &ispin_,
     &nkpt_, &ikpt_, &nspinor_, &ispinor_, ln);
  if (!lstat)
    return FALSE;

  if (norbu)   *norbu   = norbu_;
  if (norbd)   *norbd   = norbd_;
  if (nkpt)    *nkpt    = nkpt_;
  if (nspinor) *nspinor = nspinor_;

  if (iorb)    *iorb    = iorb_;
  if (ispin)   *ispin   = ispin_;
  if (ikpt)    *ikpt    = ikpt_;
  if (ispinor) *ispinor = ispinor_;

  return TRUE;
}

/******************************************/
/* Devel. version of a wavefunction type. */
/******************************************/
static void bigdft_wf_dispose(GObject *atoms);
static void bigdft_wf_finalize(GObject *atoms);

#ifdef HAVE_GLIB
enum {
  PSI_READY_SIGNAL,
  HPSI_READY_SIGNAL,
  ONE_WAVE_READY_SIGNAL,
  LAST_SIGNAL
};

enum
  {
    WF_PROP_0,
    INPUT_PROP,
    FORMAT_PROP
  };

G_DEFINE_TYPE(BigDFT_Wf, bigdft_wf, BIGDFT_ORBS_TYPE)

static guint bigdft_wf_signals[LAST_SIGNAL] = { 0 };

static void bigdft_wf_get_property(GObject* obj, guint property_id,
                                   GValue *value, GParamSpec *pspec);
static void bigdft_wf_set_property(GObject* obj, guint property_id,
                                   const GValue *value, GParamSpec *pspec);

static void g_cclosure_marshal_ONE_WAVE(GClosure *closure,
                                        GValue *return_value,
                                        guint n_param_values,
                                        const GValue *param_values,
                                        gpointer invocation_hint,
                                        gpointer marshal_data)
{
  typedef void (*callbackFunc)(gpointer data1, guint iter, GArray *arg_psi, guint arg_ipsi,
                               guint arg_kpt, guint arg_orb, guint arg_spin, gpointer data2);
  register callbackFunc callback;
  register GCClosure *cc = (GCClosure*)closure;
  register gpointer data1, data2;

  g_return_if_fail(n_param_values == 7);

  if (G_CCLOSURE_SWAP_DATA(closure))
    {
      data1 = closure->data;
      data2 = g_value_peek_pointer(param_values + 0);
    }
  else
    {
      data1 = g_value_peek_pointer(param_values + 0);
      data2 = closure->data;
    }
  callback = (callbackFunc)(size_t)(marshal_data ? marshal_data : cc->callback);

  callback(data1, g_value_get_uint(param_values + 1),
           (GArray*)g_value_get_boxed(param_values + 2),
           g_value_get_uint(param_values + 3), 
           g_value_get_uint(param_values + 4), 
           g_value_get_uint(param_values + 5), 
           g_value_get_uint(param_values + 6), data2);
}

static void bigdft_wf_class_init(BigDFT_WfClass *klass)
{
  /* Connect the overloading methods. */
  G_OBJECT_CLASS(klass)->dispose      = bigdft_wf_dispose;
  G_OBJECT_CLASS(klass)->finalize     = bigdft_wf_finalize;
  G_OBJECT_CLASS(klass)->set_property = bigdft_wf_set_property;
  G_OBJECT_CLASS(klass)->get_property = bigdft_wf_get_property;

  bigdft_wf_signals[PSI_READY_SIGNAL] =
    g_signal_new("psi-ready", G_TYPE_FROM_CLASS(klass),
                 G_SIGNAL_RUN_LAST | G_SIGNAL_NO_RECURSE | G_SIGNAL_NO_HOOKS,
		 0, NULL, NULL, g_cclosure_marshal_VOID__UINT,
                 G_TYPE_NONE, 1, G_TYPE_UINT, NULL);

  bigdft_wf_signals[HPSI_READY_SIGNAL] =
    g_signal_new("hpsi-ready", G_TYPE_FROM_CLASS(klass),
                 G_SIGNAL_RUN_LAST | G_SIGNAL_NO_RECURSE | G_SIGNAL_NO_HOOKS,
		 0, NULL, NULL, g_cclosure_marshal_VOID__UINT,
                 G_TYPE_NONE, 1, G_TYPE_UINT, NULL);

  bigdft_wf_signals[ONE_WAVE_READY_SIGNAL] =
    g_signal_new("one-wave-ready", G_TYPE_FROM_CLASS(klass),
                 G_SIGNAL_RUN_LAST | G_SIGNAL_NO_RECURSE | G_SIGNAL_NO_HOOKS | G_SIGNAL_DETAILED,
		 0, NULL, NULL, g_cclosure_marshal_ONE_WAVE,
                 G_TYPE_NONE, 6, G_TYPE_UINT, G_TYPE_ARRAY, G_TYPE_UINT,
                 G_TYPE_UINT, G_TYPE_UINT, G_TYPE_UINT, NULL);

  g_object_class_install_property(G_OBJECT_CLASS(klass), INPUT_PROP,
				  g_param_spec_int("init-id", "Initialisation method",
                                                   "Method used to initialise these wavefunctions.",
                                                   -1000, 101, 0, G_PARAM_READABLE));
  g_object_class_install_property(G_OBJECT_CLASS(klass), FORMAT_PROP,
				  g_param_spec_uint("disk-format", "Format when on disk",
                                                    "Format to read or write wavefunctions to disk.",
                                                    0, 3, 0, G_PARAM_READABLE));
}

static void bigdft_wf_get_property(GObject* obj, guint property_id,
                                   GValue *value, GParamSpec *pspec)
{
  BigDFT_Wf *self = BIGDFT_WF(obj);

  switch (property_id)
    {
    case INPUT_PROP:
      g_value_set_int(value, self->inputpsi);
      break;
    case FORMAT_PROP:
      g_value_set_uint(value, self->input_wf_format);
      break;
    default:
      /* We don't have any other property... */
      G_OBJECT_WARN_INVALID_PROPERTY_ID(obj, property_id, pspec);
      break;
    }
}
static void bigdft_wf_set_property(GObject* obj, guint property_id,
                                   const GValue *value, GParamSpec *pspec)
{
  switch (property_id)
    {
    default:
      /* We don't have any other property... */
      G_OBJECT_WARN_INVALID_PROPERTY_ID(obj, property_id, pspec);
      break;
    }
}
#endif

static void bigdft_wf_init(BigDFT_Wf *obj)
{
#ifdef HAVE_GLIB
  memset((void*)((char*)obj + sizeof(BigDFT_Orbs)), 0, sizeof(BigDFT_Wf) - sizeof(BigDFT_Orbs));
#else
  memset(obj, 0, sizeof(BigDFT_Wf));
#endif
}
static void bigdft_wf_dispose(GObject *obj)
{
#ifdef HAVE_GLIB
  BigDFT_Wf *wf = BIGDFT_WF(obj);

  if (wf->dispose_has_run)
    return;
  wf->dispose_has_run = TRUE;

  wf->parent.data = (void*)0;
  wf->parent.comm = (void*)0;

  /* Destroy only the C wrappers. */
  wf->lzd->data = (void*)0;
  g_object_unref(G_OBJECT(wf->lzd));

  if (wf->data)
    FC_FUNC_(wf_empty, WF_EMPTY)(wf->data);

  /* Chain up to the parent class */
  G_OBJECT_CLASS(bigdft_wf_parent_class)->dispose(obj);
#endif
}
static void bigdft_wf_finalize(GObject *obj)
{
  BigDFT_Wf *wf = BIGDFT_WF(obj);

  if (wf->data)
    FC_FUNC_(wf_free, WF_FREE)(&wf->data);

#ifdef HAVE_GLIB
  G_OBJECT_CLASS(bigdft_wf_parent_class)->finalize(obj);
  /* g_debug("Freeing wf object %p done.\n", obj); */
#endif
}
void FC_FUNC_(wf_emit_psi, WF_EMIT_PSI)(BigDFT_Wf **wf, guint *istep)
{
  BigDFT_Orbs *orbs;

  orbs = &(*wf)->parent;
  GET_ATTR_DBL(orbs, ORBS, occup, OCCUP);
  GET_ATTR_DBL(orbs, ORBS, eval,  EVAL);
#ifdef HAVE_GLIB
  g_return_if_fail(bigdft_lzd_check((*wf)->lzd));
  g_signal_emit(G_OBJECT(*wf), bigdft_wf_signals[PSI_READY_SIGNAL],
                0 /* details */, *istep, NULL);
#endif  
}
void FC_FUNC_(wf_emit_hpsi, WF_EMIT_HPSI)(BigDFT_Wf **wf, guint *istep)
{
#ifdef HAVE_GLIB
  g_return_if_fail(bigdft_lzd_check((*wf)->lzd));
  g_signal_emit(G_OBJECT(*wf), bigdft_wf_signals[HPSI_READY_SIGNAL],
                0 /* details */, *istep, NULL);
#endif  
}
void FC_FUNC_(wf_emit_lzd, WF_EMIT_LZD)(BigDFT_Wf **wf)
{
  BigDFT_Orbs *orbs;

  orbs = &(*wf)->parent;
  GET_ATTR_UINT  (orbs, ORBS, inwhichlocreg, INWHICHLOCREG);

  bigdft_lzd_emit_defined((*wf)->lzd);
}
#ifdef HAVE_GLIB
void bigdft_wf_emit_one_wave(BigDFT_Wf *wf, guint iter, GArray *psic,
                             GQuark quark, BigDFT_PsiId ipsi, guint ikpt, guint iorb, BigDFT_Spin ispin)
{
  g_signal_emit(G_OBJECT(wf), bigdft_wf_signals[ONE_WAVE_READY_SIGNAL],
                quark, iter, psic, ipsi, ikpt, iorb, ispin, NULL);
}
#endif  

BigDFT_Wf* bigdft_wf_new(int inputPsiId)
{
  long self;
  BigDFT_Wf *wf;
  gboolean linear;

  FC_FUNC_(inputs_get_linear, INPUTS_GET_LINEAR)(&linear, &inputPsiId);
    
#ifdef HAVE_GLIB
  wf = BIGDFT_WF(g_object_new(BIGDFT_WF_TYPE, "linear", linear, NULL));
#else
  wf = g_malloc(sizeof(BigDFT_Wf));
  bigdft_wf_init(wf);
  wf->parent.linear = linear;
#endif
  self = *((long*)&wf);
  FC_FUNC_(wf_new, WF_NEW)(&self, &wf->data, &wf->parent.data, &wf->parent.comm,
                           &wf->data_lzd);
  FC_FUNC_(orbs_init, ORBS_INIT)(wf->parent.data);
  FC_FUNC_(wf_get_psi, WF_GET_PSI)(wf->data, (long*)&wf->psi, (long*)&wf->hpsi);

  wf->lzd = bigdft_lzd_new_with_fortran(wf->data_lzd);

  wf->inputpsi = inputPsiId;

  return wf;
}
void FC_FUNC_(wf_new_wrapper, WF_NEW_WRAPPER)(long *self, void *obj, int *linear)
{
  BigDFT_Wf *wf;

  wf = bigdft_wf_new_from_fortran(obj, *linear);
  *self = *((long*)&wf);
}
BigDFT_Wf* bigdft_wf_new_from_fortran(void *obj, gboolean linear)
{
  BigDFT_Wf *wf;
  BigDFT_Orbs *orbs;

#ifdef HAVE_GLIB
  wf = BIGDFT_WF(g_object_new(BIGDFT_WF_TYPE, "linear", linear, NULL));
#else
  wf = g_malloc(sizeof(BigDFT_Wf));
  wf->parent.linear = linear;
  bigdft_wf_init(wf);
#endif
  wf->data = obj;
  FC_FUNC_(wf_get_data, WF_GET_DATA)(wf->data, &wf->parent.data, &wf->parent.comm,
                                     &wf->data_lzd);
  FC_FUNC_(wf_get_psi, WF_GET_PSI)(wf->data, (long*)&wf->psi, (long*)&wf->hpsi);

  wf->lzd = bigdft_lzd_new_from_fortran(wf->data_lzd);

  orbs = &wf->parent;
  FC_FUNC_(orbs_get_dimensions, ORBS_GET_DIMENSIONS)(orbs->data, (int*)&orbs->norb,
                                                     (int*)&orbs->norbp, (int*)&orbs->norbu,
                                                     (int*)&orbs->norbd, (int*)&orbs->nspin,
                                                     (int*)&orbs->nspinor, (int*)&orbs->npsidim,
                                                     (int*)&orbs->nkpts, (int*)&orbs->nkptsp,
                                                     (int*)&orbs->isorb, (int*)&orbs->iskpts);
  GET_ATTR_DBL   (orbs, ORBS, occup,         OCCUP);
  GET_ATTR_DBL   (orbs, ORBS, kwgts,         KWGTS);
  GET_ATTR_DBL_2D(orbs, ORBS, kpts,          KPTS);
  GET_ATTR_UINT  (orbs, ORBS, inwhichlocreg, INWHICHLOCREG);
  GET_ATTR_UINT  (orbs, ORBS, onwhichmpi,    ONWHICHMPI);
  GET_ATTR_UINT  (orbs, ORBS, onwhichatom,   ONWHICHATOM);

  return wf;
}
void FC_FUNC_(wf_free_wrapper, WF_FREE_WRAPPER)(gpointer *obj)
{
  BigDFT_Wf *wf = BIGDFT_WF(*obj);

  wf->data = (gpointer)0;
  bigdft_wf_free(wf);
}
void bigdft_wf_free(BigDFT_Wf *wf)
{
#ifdef HAVE_GLIB
  g_object_unref(G_OBJECT(wf));
#else
  bigdft_wf_finalize(wf);
  g_free(wf);
#endif
}
void FC_FUNC_(wf_copy_from_fortran, WF_COPY_FROM_FORTRAN)
     (gpointer *self, const double *radii, const double *crmult, const double *frmult)
{
  BigDFT_Wf *wf = BIGDFT_WF(*self);
  GArray *arr;
  guint nele;

  nele = 3 * BIGDFT_ATOMS(wf->lzd)->nat;
#ifdef HAVE_GLIB
  arr = g_array_sized_new(FALSE, FALSE, sizeof(double), nele);
  arr = g_array_set_size(arr, nele);
  memcpy(arr->data, radii, sizeof(double) * nele);
#else
  arr = radii;
#endif
  bigdft_lzd_copy_from_fortran(wf->lzd, arr, *crmult, *frmult);
#ifdef HAVE_GLIB
  g_array_unref(arr);
#endif
}
guint bigdft_wf_define(BigDFT_Wf *wf, const BigDFT_Inputs *in, guint iproc, guint nproc)
{
  int nelec, ln, lnpsidim_orbs, lnpsidim_comp;
  const gchar *dir = "data";
  BigDFT_Orbs *orbs;

  orbs = &wf->parent;
  nelec = bigdft_orbs_define(orbs, &wf->lzd->parent, in, iproc, nproc);

  ln = strlen(dir);
  FC_FUNC_(inputs_check_psi_id, INPUTS_CHECK_PSI_ID)
    (&wf->inputpsi, (int*)&wf->input_wf_format, dir, &ln, orbs->data, orbs->lorbs,
     (int*)&iproc, (int*)&nproc, strlen(dir));

  FC_FUNC_(wf_empty, WF_EMPTY)(wf->data);

  bigdft_lzd_define(wf->lzd, in->linear, orbs, iproc, nproc);
  if (wf->parent.linear)
    {
      FC_FUNC_(update_wavefunctions_size, UPDATE_WAVEFUNCTIONS_SIZE)
        (wf->lzd->data, &lnpsidim_orbs, &lnpsidim_comp, orbs->lorbs,
         (int*)&iproc, (int*)&nproc);
    }

  return nelec;
}
void bigdft_wf_init_linear_comm(BigDFT_Wf *wf, const BigDFT_LocalFields *denspot,
                                const BigDFT_Inputs *in, guint iproc, guint nproc)
{
  if (!wf->parent.linear)
    return;

  FC_FUNC_(kswfn_init_comm, KSWFN_INIT_COMM)(wf->data, 
                                             denspot->dpbox,
                                             (int*)&iproc, (int*)&nproc);
}
void bigdft_wf_calculate_psi0(BigDFT_Wf *wf, BigDFT_LocalFields *denspot,
                              BigDFT_Proj *proj, BigDFT_Goutput *energs,
                              guint iproc, guint nproc)
{
  int norbv;
  void *GPU;
  void *tmb, *orbs_, *comm, *lzd;
  BigDFT_Orbs *orbs;
  long self;
  double big[4096];

  FC_FUNC_(gpu_new, GPU_NEW)(&GPU);
  self = *((long*)&tmb);
  FC_FUNC_(wf_new, WF_NEW)(&self, &tmb, &orbs_, &comm, &lzd);
  FC_FUNC_(input_wf, INPUT_WF)((int*)&iproc, (int*)&nproc, wf->parent.in->data, GPU,
                               BIGDFT_ATOMS(wf->lzd)->data,
                               BIGDFT_ATOMS(wf->lzd)->rxyz.data,
                               denspot->data, big, proj->nlpspd, &proj->proj,
                               wf->data, tmb, energs->data, &wf->inputpsi,
                               (int*)&wf->input_wf_format, &norbv,
                               (void*)0, (f90_pointer_double*)0, (void*)0,
                               (double*)0, (double*)0,
                               (double*)0, (double*)0, (void*)0);
  FC_FUNC_(gpu_free, GPU_FREE)(&GPU);
  FC_FUNC_(wf_free, WF_FREE)(&tmb);
  orbs = &wf->parent;
  GET_ATTR_DBL(orbs, ORBS, eval,  EVAL);
}
guint bigdft_wf_optimization_loop(BigDFT_Wf *wf, BigDFT_LocalFields *denspot,
                                  BigDFT_Proj *proj, BigDFT_Goutput *energs,
                                  BigDFT_OptLoop *params, guint iproc, guint nproc)
{
  guint infocode;
  guint inputpsi = 0;
  double xcstr[6];
  void *GPU;
  guint idsx = 6;
  double alphamix = 0.;
  BigDFT_OptLoop *p;

  if (params)
    p = params;
  else
    p = bigdft_optloop_new();

#ifdef HAVE_GLIB
  g_object_ref(G_OBJECT(wf));
  g_object_ref(G_OBJECT(denspot));
  g_object_ref(G_OBJECT(proj));
  g_object_ref(G_OBJECT(energs));
  g_object_ref(G_OBJECT(p));
#endif

  FC_FUNC_(gpu_new, GPU_NEW)(&GPU);
  FC_FUNC_(kswfn_optimization_loop, KSWFN_OPTIMIZATION_LOOP)
    ((int*)&iproc, (int*)&nproc, p->data, &alphamix, (int*)&idsx, (int*)&inputpsi,
     wf->data, denspot->data, proj->nlpspd, &proj->proj,
     energs->data, BIGDFT_ATOMS(wf->lzd)->data, BIGDFT_ATOMS(wf->lzd)->rxyz.data,
     GPU, xcstr, wf->parent.in->data);
  FC_FUNC_(energs_copy_data, ENERGS_COPY_DATA)
    (energs->data, &energs->eh, &energs->exc,
     &energs->evxc, &energs->eion, &energs->edisp,
     &energs->ekin, &energs->epot, &energs->eproj,
     &energs->eexctX, &energs->ebs, &energs->eKS,
     &energs->trH, &energs->evsum, &energs->evsic);
  bigdft_optloop_copy_from_fortran(p);
  FC_FUNC_(gpu_free, GPU_FREE)(&GPU);
  infocode = p->infocode;

#ifdef HAVE_GLIB
  g_object_unref(G_OBJECT(wf));
  g_object_unref(G_OBJECT(denspot));
  g_object_unref(G_OBJECT(proj));
  g_object_unref(G_OBJECT(energs));
  g_object_unref(G_OBJECT(p));
#endif

  if (!params)
    bigdft_optloop_free(p);

  return infocode;
}
void bigdft_wf_post_treatments(BigDFT_Wf *wf, BigDFT_LocalFields *denspot,
                               BigDFT_Proj *proj, BigDFT_Goutput *energs,
                               guint iproc, guint nproc)
{
  void *GPU;
  guint n;
  int output_denspot = 0, refill_proj = 0, calculate_dipole = 0;
  char dir[2] = "  ", gridformat[5] = ".cube";
  double *fpulay;

  n = 3 * BIGDFT_ATOMS(wf->lzd)->nat;
  fpulay = g_malloc(sizeof(double) * n);
  memset(fpulay, 0, sizeof(double) * n);
  energs->nat  = BIGDFT_ATOMS(wf->lzd)->nat;
  energs->fxyz = g_malloc(sizeof(double) * n);
  FC_FUNC_(gpu_new, GPU_NEW)(&GPU);
  FC_FUNC_(kswfn_post_treatments, KSWFN_POST_TREATMENTS)
    ((int*)&iproc, (int*)&nproc, wf->data, wf->data, &wf->parent.linear,
     energs->fxyz, &energs->fnoise,
     denspot->fion.data, denspot->fdisp.data, fpulay,
     energs->strten, &energs->pressure, denspot->ewaldstr, denspot->xcstr, GPU, energs->data,
     denspot->data, BIGDFT_ATOMS(wf->lzd)->data, BIGDFT_ATOMS(wf->lzd)->rxyz.data,
     proj->nlpspd, &proj->proj, &output_denspot, dir, gridformat, &refill_proj,
     &calculate_dipole, 2, 5);
  FC_FUNC_(gpu_free, GPU_FREE)(&GPU);
  g_free(fpulay);
}
static BigDFT_Locreg* _wf_get_locreg(const BigDFT_Wf *wf, guint iorbp)
{
  if (!bigdft_orbs_get_linear(&wf->parent))
    return &wf->lzd->parent;
  else
    {
#ifdef HAVE_GLIB
      g_return_val_if_fail(iorbp < wf->parent.norb, (BigDFT_Locreg*)0);
      g_return_val_if_fail(wf->parent.inwhichlocreg[iorbp] <= wf->lzd->nlr, (BigDFT_Locreg*)0);
#endif
      return wf->lzd->Llr[wf->parent.inwhichlocreg[iorbp] - 1];
    }
}
static void _wf_get_psi_start_size(const BigDFT_Wf *wf, guint iorbp, guint isorb,
                                   guint *psis, guint *orbSize)
{
  BigDFT_Locreg *lr;
  guint i, orbSize_;

  lr = _wf_get_locreg(wf, iorbp + isorb);
#ifdef HAVE_GLIB
  g_return_if_fail(lr);
#endif
  FC_FUNC_(glr_get_psi_size, GLR_GET_PSI_SIZE)(lr->data, (int*)orbSize);

  if (!bigdft_orbs_get_linear(&wf->parent))
    *psis = iorbp * *orbSize;
  else
    {
      *psis = 0;
      for (i = 0; i < iorbp; i++)
        {
          lr = _wf_get_locreg(wf, i + isorb);
#ifdef HAVE_GLIB
          g_return_if_fail(lr);
#endif
          FC_FUNC_(glr_get_psi_size, GLR_GET_PSI_SIZE)(lr->data, (int*)&orbSize_);
          *psis += orbSize_;
        }
    }
  *psis *= wf->parent.nspinor;
}
static gboolean _wf_get_compress(const BigDFT_Wf *wf,
                                 guint ikpt, guint iorb, BigDFT_Spin ispin, BigDFT_Spinor ispinor,
                                 guint *psiSize, int *jproc, guint *dpsi)
{
  guint orbSize;
  int iorbp, isorb;
  long psiAlloc;

  *psiSize = 0;
  if (!_orbs_get_iorbp(&wf->parent, ikpt, iorb, ispin, ispinor, &iorbp, &isorb, jproc))
    return FALSE;
  
  _wf_get_psi_start_size(wf, (guint)iorbp, (guint)isorb, dpsi, &orbSize);
  if (ispinor == BIGDFT_IMAG && wf->parent.nspinor == 2)
    *dpsi += orbSize;

  /* Dimension checks. */
  FC_FUNC_(wf_get_psi_size, WF_GET_PSI_SIZE)(wf->psi, &psiAlloc);
  if ((long)*dpsi >= psiAlloc)
    {
      fprintf(stderr, "WARNING: inconsistency in psi allocation"
              " size (%ld) and accessor (%d).\n", psiAlloc, *dpsi);
      return FALSE;
    }

  *psiSize = orbSize;
  if (ispinor == BIGDFT_PARTIAL_DENSITY && wf->parent.nspinor == 2)
    *psiSize *= 2;

  return TRUE;
}
const double* bigdft_wf_get_compress(const BigDFT_Wf *wf, BigDFT_PsiId ipsi,
                                     guint ikpt, guint iorb, BigDFT_Spin ispin, BigDFT_Spinor ispinor,
                                     guint *psiSize, guint iproc)
{
  guint dpsi;
  int jproc;
  f90_pointer_double *data;

  if (!_wf_get_compress(wf, ikpt, iorb, ispin, ispinor, psiSize, &jproc, &dpsi))
    return (const double*)0;
    
  switch (ipsi)
    {
    case (BIGDFT_HPSI):
      data = wf->hpsi;
      break;
    case (BIGDFT_PSI):
    default:
      data = wf->psi;
      break;
    }
  if (!data || !data->data)
    {
      fprintf(stderr, "WARNING: psi data are not available.\n");
      return (const double*)0;
    }

  return (iproc == (guint)jproc)?data->data + dpsi:(const double*)0;
}
const double* bigdft_wf_get_psi_compress(const BigDFT_Wf *wf, guint ikpt, guint iorb,
                                         BigDFT_Spin ispin, BigDFT_Spinor ispinor,
                                         guint *psiSize, guint iproc)
{
  return bigdft_wf_get_compress(wf, BIGDFT_PSI, ikpt, iorb, ispin, ispinor, psiSize, iproc);
}
const double* bigdft_wf_get_hpsi_compress(const BigDFT_Wf *wf, guint ikpt, guint iorb,
                                          BigDFT_Spin ispin, BigDFT_Spinor ispinor,
                                          guint *psiSize, guint iproc)
{
  return bigdft_wf_get_compress(wf, BIGDFT_HPSI, ikpt, iorb, ispin, ispinor, psiSize, iproc);
}
gboolean bigdft_wf_copy_compress(const BigDFT_Wf *wf, BigDFT_PsiId ipsi,
                                 guint ikpt, guint iorb, BigDFT_Spin ispin, BigDFT_Spinor ispinor,
                                 guint iproc, double *psic, guint psiAlloc)
{
  int dpsi_, psiAlloc_;
  guint dpsi, psiSize;
  int jproc;
  f90_pointer_double *data;

  switch (ipsi)
    {
    case (BIGDFT_HPSI):
      data = wf->hpsi;
      break;
    case (BIGDFT_PSI):
    default:
      data = wf->psi;
      break;
    }
  if (!data || !data->data)
    {
      fprintf(stderr, "WARNING: psi data are not available.\n");
      return FALSE;
    }

  if (!_wf_get_compress(wf, ikpt, iorb, ispin, ispinor, &psiSize, &jproc, &dpsi))
    return FALSE;
  if (psiSize != psiAlloc)
    return FALSE;

  if (iproc == (guint)jproc)
    memcpy(psic, data->data + dpsi, sizeof(double) * psiAlloc);
  else
    {
      psiAlloc_ = psiAlloc;
      dpsi_ = dpsi;
      FC_FUNC_(kswfn_mpi_copy, KSWFN_MPI_COPY)(psic, &jproc, &dpsi_, &psiAlloc_);
    }
  
  return TRUE;
}
gboolean bigdft_wf_copy_psi_compress(const BigDFT_Wf *wf, guint ikpt, guint iorb,
                                     BigDFT_Spin ispin, BigDFT_Spinor ispinor,
                                     guint iproc, double *psic, guint psiAlloc)
{
  return bigdft_wf_copy_compress(wf, BIGDFT_PSI, ikpt, iorb, ispin, ispinor, iproc, psic, psiAlloc);
}
gboolean bigdft_wf_copy_hpsi_compress(const BigDFT_Wf *wf, guint ikpt, guint iorb,
                                      BigDFT_Spin ispin, BigDFT_Spinor ispinor,
                                      guint iproc, double *psic, guint psiAlloc)
{
  return bigdft_wf_copy_compress(wf, BIGDFT_HPSI, ikpt, iorb, ispin, ispinor, iproc, psic, psiAlloc);
}
void bigdft_wf_write_psi_compress(const BigDFT_Wf *wf, const gchar *filename,
                                  BigDFT_WfFileFormats format, const double *psic,
                                  guint ikpt, guint iorb, BigDFT_Spin ispin, guint psiSize)
{
  guint unitwf = 99, ln, ispinor;
  int iorbp, isorb, jproc;

  ln = strlen(filename);
  for (ispinor = 1; ispinor <= wf->parent.nspinor; ispinor++)
    {
      _orbs_get_iorbp(&wf->parent, ikpt, iorb, ispin, ispinor - 1, &iorbp, &isorb, &jproc);
      iorbp += 1;
      FC_FUNC_(orbs_open_file, ORBS_OPEN_FILE)(wf->parent.data, (int*)&unitwf,
                                               filename, (int*)&ln,
                                               (int*)&format, &iorbp, (int*)&ispinor, ln);
      bigdft_locreg_write_psi_compress(wf->lzd->Llr[wf->parent.inwhichlocreg[iorbp + isorb - 1] - 1],
                                       unitwf, format, wf->parent.linear, iorbp + isorb,
                                       wf->lzd->parent.n, psic + psiSize * (ispinor - 1));
      FC_FUNC_(close_file, CLOSE_FILE)((int*)&unitwf);
    }
}
double* bigdft_wf_convert_to_isf(const BigDFT_Wf *wf, guint ikpt, guint iorb,
                                 BigDFT_Spin ispin, BigDFT_Spinor ispinor, guint iproc)
{
  guint psiSize, i, n;
  const double *psic;
  double *psir, *psii;
  BigDFT_Locreg *lr;

  psic = bigdft_wf_get_psi_compress(wf, ikpt, iorb, ispin, ispinor, &psiSize, iproc);
  if (!psic)
    return (double *)0;
  
  lr = bigdft_wf_get_locreg(wf, ikpt, iorb, ispin, iproc);
  if (!lr)
    return (double *)0;
  psir = bigdft_locreg_convert_to_isf(lr, psic);
  if (ispinor == BIGDFT_PARTIAL_DENSITY)
    {
      n = lr->ni[0] * lr->ni[1] * lr->ni[2];
      if (wf->parent.nspinor == 2)
        {
          psii = bigdft_locreg_convert_to_isf(lr, psic + psiSize / 2);
          for(i = 0; i < n; i++)
            psir[i] = psir[i] * psir[i] + psii[i] * psii[i];
          g_free(psii);
        }
      else
        for(i = 0; i < n; i++)
          psir[i] *= psir[i];;
    }

  return psir;
}
/**
 * bigdft_wf_get_locreg:
 * @wf: 
 * @ikpt: 
 * @iorb: 
 * @ispin: 
 * @iproc: 
 *
 * 
 *
 * Returns: (transfer none):
 **/
BigDFT_Locreg* bigdft_wf_get_locreg(const BigDFT_Wf *wf, guint ikpt, guint iorb,
                                    BigDFT_Spin ispin, guint iproc)
{
  int iorbp, isorb, jproc;

  if (!bigdft_orbs_get_linear(&wf->parent))
    return &wf->lzd->parent;

  if (!_orbs_get_iorbp(&wf->parent, ikpt, iorb, ispin, BIGDFT_REAL, &iorbp, &isorb, &jproc) || jproc != iproc)
    return (BigDFT_Locreg*)0;
  
  return wf->lzd->Llr[wf->parent.inwhichlocreg[iorbp + isorb] - 1];
}

typedef struct bigdft_data
{
  guint                iproc, nproc;
  const BigDFT_Inputs *in;
  BigDFT_Proj         *proj;
  BigDFT_LocalFields  *denspot;
  BigDFT_Wf           *wf;
  BigDFT_Goutput       *energs;
  BigDFT_OptLoop      *optloop;
} BigDFT_Data;
static gpointer wf_optimization_thread(gpointer data)
{
  BigDFT_Data *ct = (BigDFT_Data*)data;
  
  bigdft_localfields_create_poisson_kernels(ct->denspot);
  bigdft_localfields_create_effective_ionic_pot(ct->denspot, ct->wf->lzd,
                                                ct->in, ct->iproc, ct->nproc);
  if (ct->wf->parent.linear)
    FC_FUNC_(kswfn_init_comm, KSWFN_INIT_COMM)(ct->wf->data,
                                               ct->denspot->dpbox,
                                               (int*)&ct->iproc, (int*)&ct->nproc);
  bigdft_wf_calculate_psi0(ct->wf, ct->denspot, ct->proj, ct->energs, ct->iproc, ct->nproc);
  bigdft_wf_optimization_loop(ct->wf, ct->denspot, ct->proj, ct->energs, ct->optloop,
                              ct->iproc, ct->nproc);
#ifdef HAVE_GLIB
  g_object_unref(G_OBJECT(ct->wf));
  g_object_unref(G_OBJECT(ct->denspot));
  g_object_unref(G_OBJECT(ct->energs));
  g_object_unref(G_OBJECT(ct->proj));
  g_object_unref(G_OBJECT(ct->optloop));
#endif
  g_free(ct);

  return (gpointer)0;
}
void bigdft_wf_optimization(BigDFT_Wf *wf, BigDFT_Proj *proj, BigDFT_LocalFields *denspot,
                            BigDFT_Goutput *energs, BigDFT_OptLoop *params, const BigDFT_Inputs *in,
                            gboolean threaded, guint iproc, guint nproc)
{
  BigDFT_Data *ct;
#ifdef HAVE_GLIB
  GError *error = (GError*)0;
#endif

  ct = g_malloc(sizeof(BigDFT_Data));
  ct->iproc   = iproc;
  ct->nproc   = nproc;
  ct->denspot = denspot;
  ct->in      = in;
  ct->proj    = proj;
  ct->wf      = wf;
  ct->energs  = energs;
  ct->optloop = params;
#ifdef HAVE_GLIB
  g_object_ref(G_OBJECT(wf));
  g_object_ref(G_OBJECT(denspot));
  g_object_ref(G_OBJECT(proj));
  g_object_ref(G_OBJECT(energs));
  g_object_ref(G_OBJECT(params));
#endif
#ifdef G_THREADS_ENABLED
  if (threaded)
    g_thread_create(wf_optimization_thread, ct, FALSE, &error);
  else
    wf_optimization_thread(ct);
#else
  wf_optimization_thread(ct);
#endif
}
