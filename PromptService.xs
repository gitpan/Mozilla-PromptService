#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include <mozilla/nsIGenericFactory.h>
#include <mozilla/nsIComponentRegistrar.h>
#include <mozilla/nsIPromptService.h>
#include <mozilla/nsCOMPtr.h>
#include <mozilla/nsXPCOM.h>
#include <mozilla/string/nsString.h>

static SV *_callbacks;

static int find_callback(const char *name, SV **res) {
	SV **cb;
	int err = -1;

	cb = hv_fetch((HV *) SvRV(_callbacks), name, strlen(name), FALSE);
	if (cb) {
		err = 0;
		goto out;
	}

	cb = hv_fetch((HV *) SvRV(_callbacks), "DEFAULT", 7, FALSE);
	if (cb)
		err = 1;
out:
	*res = cb ? *cb : 0;
	return err;
}

static SV *wrap_dom_window(nsIDOMWindow *parent) {
	SV *obj_ref;
	SV *obj;

	obj_ref = newSViv(0);
	obj = newSVrv(obj_ref, "Mozilla::DOM::Window");
	sv_setiv(obj, (IV) parent);
	SvREADONLY_on(obj);
	return obj_ref;
}

static SV *wrap_unichar_string(const PRUnichar *uni_str) {
	const char * u8str;
	NS_ConvertUTF16toUTF8 utf8(uni_str);

	u8str = utf8.get();
	return newSVpv(u8str, 0);
}

#define END_CALL(N) \
	dSP;\
	SV *cb;\
	int fres = find_callback(#N, &cb);\
\
	if (fres && !cb) {\
		croak("# failed find_callback for " #N);\
		return NS_OK;\
	}\
	ENTER;\
	SAVETMPS;\
	PUSHMARK(SP);\
	if (fres) {\
		XPUSHs(sv_2mortal(newSVpv(#N, 0)));\
	}\
	XPUSHs(sv_2mortal(wrap_dom_window(aParent)));\
	XPUSHs(sv_2mortal(wrap_unichar_string(aDialogTitle)));\
	XPUSHs(sv_2mortal(wrap_unichar_string(aDialogText)));\
	PUTBACK;\
\
	call_sv(cb, G_DISCARD);\
	return NS_OK;

class nsIDOMWindow;
class MyPromptService : public nsIPromptService
{
public:
    NS_DECL_ISUPPORTS
    NS_DECL_NSIPROMPTSERVICE
};


NS_IMPL_ISUPPORTS1(MyPromptService, nsIPromptService)

NS_IMETHODIMP
MyPromptService::Alert(nsIDOMWindow* aParent, const PRUnichar* aDialogTitle,
                        const PRUnichar* aDialogText)
{
	END_CALL(Alert)
}

NS_IMETHODIMP
MyPromptService::AlertCheck(nsIDOMWindow* aParent,
                             const PRUnichar* aDialogTitle,
                             const PRUnichar* aDialogText,
                             const PRUnichar* aCheckMsg, PRBool* aCheckValue)
{
	END_CALL(AlertCheck)
}

NS_IMETHODIMP
MyPromptService::Confirm(nsIDOMWindow* aParent,
                          const PRUnichar* aDialogTitle,
                          const PRUnichar* aDialogText, PRBool* aConfirm)
{
	END_CALL(Confirm)
}

NS_IMETHODIMP
MyPromptService::ConfirmCheck(nsIDOMWindow* aParent,
                               const PRUnichar* aDialogTitle,
                               const PRUnichar* aDialogText,
                               const PRUnichar* aCheckMsg,
                               PRBool* aCheckValue, PRBool* aConfirm)
{
	END_CALL(ConfirmCheck)
}

NS_IMETHODIMP
MyPromptService::ConfirmEx(nsIDOMWindow* aParent,
                            const PRUnichar* aDialogTitle,
                            const PRUnichar* aDialogText,
                            PRUint32 aButtonFlags,
                            const PRUnichar* aButton0Title,
                            const PRUnichar* aButton1Title,
                            const PRUnichar* aButton2Title,
                            const PRUnichar* aCheckMsg, PRBool* aCheckValue,
                            PRInt32* aRetVal)
{
	END_CALL(ConfirmEx)
}

NS_IMETHODIMP
MyPromptService::Prompt(nsIDOMWindow* aParent, const PRUnichar* aDialogTitle,
                         const PRUnichar* aDialogText, PRUnichar** aValue,
                         const PRUnichar* aCheckMsg, PRBool* aCheckValue,
                         PRBool* aConfirm)
{
	END_CALL(Prompt)
}

NS_IMETHODIMP
MyPromptService::PromptUsernameAndPassword(nsIDOMWindow* aParent,
                                            const PRUnichar* aDialogTitle,
                                            const PRUnichar* aDialogText,
                                            PRUnichar** aUsername,
                                            PRUnichar** aPassword,
                                            const PRUnichar* aCheckMsg,
                                            PRBool* aCheckValue,
                                            PRBool* aConfirm)
{
	END_CALL(PromptUsernameAndPassword)
}

NS_IMETHODIMP
MyPromptService::PromptPassword(nsIDOMWindow* aParent,
                                 const PRUnichar* aDialogTitle,
                                 const PRUnichar* aDialogText,
                                 PRUnichar** aPassword,
                                 const PRUnichar* aCheckMsg,
                                 PRBool* aCheckValue, PRBool* aConfirm)
{
	END_CALL(PromptPassword)
}

NS_IMETHODIMP
MyPromptService::Select(nsIDOMWindow* aParent, const PRUnichar* aDialogTitle,
                         const PRUnichar* aDialogText, PRUint32 aCount,
                         const PRUnichar** aSelectList, PRInt32* outSelection,
                         PRBool* aConfirm)
{
	END_CALL(Select)
}

NS_GENERIC_FACTORY_CONSTRUCTOR(MyPromptService)

static const nsModuleComponentInfo _prompt_info = {
	"Prompt Service",
	{ 0x95611356, 0xf583, 0x46f5, {
			     0x81, 0xff, 0x4b, 0x3e, 0x01, 0x62, 0xc6, 0x19 }
	},
	"@mozilla.org/embedcomp/prompt-service;1",
	MyPromptServiceConstructor
};

MODULE = Mozilla::PromptService		PACKAGE = Mozilla::PromptService		
int
Register(cbs)
	SV *cbs;
	INIT:
		nsCOMPtr<nsIComponentRegistrar> cr;
		nsCOMPtr<nsIGenericFactory> componentFactory;
		nsresult rv;
	CODE:
		if (_callbacks) {
			SvSetSV(_callbacks, cbs);
		} else {
			_callbacks = newSVsv(cbs);
		}

   		rv = NS_GetComponentRegistrar(getter_AddRefs(cr));
		if (NS_FAILED(rv)) {
			croak("# failed NS_GetComponentRegistrar");
			goto out_retval;
		}
		rv = NS_NewGenericFactory(getter_AddRefs(componentFactory),
				&_prompt_info);
		if (NS_FAILED(rv)) {
			croak("# failed NS_NewGenericFactory");
			goto out_retval;
		}
		rv = cr->RegisterFactory(_prompt_info.mCID
				, _prompt_info.mDescription
				, _prompt_info.mContractID
				, componentFactory);
out_retval:
		RETVAL = (rv == NS_OK);
	OUTPUT:
		RETVAL
