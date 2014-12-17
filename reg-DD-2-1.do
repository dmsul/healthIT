/*
	Regressions using data from HospCompare and AHA.

	***Assume for EHR that 0 = no; 1 = partial, 2 = full, N = no
	
	
*/

global EDITION 2

local discharge_var aha_admits


set more off
clear all

use ../dta/hIT-combineddata

cap drop temp*

gen payment = bene_tot/1e6

	* Norm benefits by some size metrics
foreach var in netoperr beds_h ftetotal {
	gen temp = `var' if year==2009
	gen temp2 = `var' if year==2008
	bys id: egen `var'_09 = max(temp)
	bys id: egen temp3 = max(temp2)
	replace `var'_09 = temp3 if `var'_09==.
	drop temp*
}

	* Normed payment variables
gen payment_rev = payment*1e6/netoperr_09
gen payment_bed = payment/beds_h_09
gen payment_fte = payment/ftetotal_09

	* Gen "post" variables
foreach var in qual_mcd payment payment_rev payment_bed payment_fte {
	gen `var'_post = `var'*post
}

	* Gen payment yearly interactions
foreach var in payment payment_bed payment_fte payment_rev {
	forval year = 2009/2011 {
		gen `var'_y`year' = `var'*(year==`year')
	}
}




	* Windsorizing cutoffs
foreach var in rev bed fte {
	_pctile payment_`var', p(99.8)
	local windsor_`var' = r(r1)
}

	* Labor productivity variables
gen nrev_per_payroll = netoperrev/paytot
gen nrev_per_fte = (netoperrev/1e6)/ftetotal
gen admits_per_payroll = admh/(paytot/1e6)
gen admits_per_fte = admh/ftetotal


*******************
**	Regressions
*******************

foreach var in payment_rev payment_bed payment_fte payment netoperrev beds_h {
	xtile temp1 = `var' if year==2009, n(5)
	bys id: egen `var'_group = max(temp1)
	summ `var'_group
	drop temp*
	forval q=1/5 {
		gen payment_bed_Q`q'_post = (payment_`var'_group==`q')*post if payment_bed<.
	}
}


local replace replace

* 1st Stage - State program launch/firstpay IV
cap log close
log using ../out/reg-DD-$EDITION-log.txt, replace text

local replace replace
foreach lhv in emr_any emr_100 {

	xtreg `lhv' payment_post _I*, fe robust
	test payment_post
	local fstat = r(F)
	outreg2 using ../out/emr-1st-$EDITION.xls, `replace' excel addstat("F-stat",`fstat')
	local replace

	xtreg `lhv' payment_y* _I*, fe robust
	outreg2 using ../out/emr-1st-$EDITION.xls, excel 
	
	
	foreach denom in bed {
	
		xtreg `lhv' payment_`denom'_post _I*, fe robust
		test payment_`denom'_post
		local fstat = r(F)
		outreg2 using ../out/emr-1st-$EDITION.xls, excel addstat("F-stat",`fstat')
	
		xtreg `lhv' payment_`denom'_y* _I*, fe robust
		outreg2 using ../out/emr-1st-$EDITION.xls, excel 
			
		xtreg `lhv' payment_`denom'_post _I* if payment_`denom'<`windsor_`denom'', fe robust
		test payment_`denom'_post
		local fstat = r(F)
		outreg2 using ../out/emr-1st-$EDITION.xls, excel addtext(Windsor, "Windsor") addstat("F-stat",`fstat')
			
		xtreg `lhv' payment_`denom'_y* _I* if payment_`denom'<`windsor_`denom'', fe robust
		outreg2 using ../out/emr-1st-$EDITION.xls, excel addtext(Windsor, "Windsor")
		
		xtreg `lhv' payment_`denom'_Q*_post _I*, fe robust
		outreg2 using ../out/emr-1st-$EDITION.xls, excel
	
		xtreg `lhv' payment_`denom'_Q*_post _I* if payment_`denom'<`windsor_`denom'', fe robust
		test payment_`denom'_post
		local fstat = r(F)
		outreg2 using ../out/emr-1st-$EDITION.xls, excel addtext(Windsor, "Windsor") 
		
	}
	
}


	* Reduced Form


local replace replace
foreach lhv in z_core z_mort z_read nrev_per_payroll nrev_per_fte admits_per_payroll admits_per_fte {

	xtreg `lhv' payment_post _I*, fe robust
	outreg2 using ../out/emr-RF-$EDITION.xls, `replace' excel
	local replace

	xtreg `lhv' payment_y* _I*, fe robust
	outreg2 using ../out/emr-RF-$EDITION.xls, excel 
	
	
	foreach denom in bed  {
	
		xtreg `lhv' payment_`denom'_post _I*, fe robust
		test payment_`denom'_post
		local fstat = r(F)
		outreg2 using ../out/emr-RF-$EDITION.xls, excel addstat("F-stat",`fstat')
	
		xtreg `lhv' payment_`denom'_y* _I*, fe robust
		outreg2 using ../out/emr-RF-$EDITION.xls, excel 
			
		xtreg `lhv' payment_`denom'_post _I* if payment_`denom'<`windsor_`denom'', fe robust
		test payment_`denom'_post
		local fstat = r(F)
		outreg2 using ../out/emr-RF-$EDITION.xls, excel addtext(Windsor, "Windsor") addstat("F-stat",`fstat')
			
		xtreg `lhv' payment_`denom'_y* _I* if payment_`denom'<`windsor_`denom'', fe robust
		outreg2 using ../out/emr-RF-$EDITION.xls, excel addtext(Windsor, "Windsor")
		
		xtreg `lhv' payment_`denom'_Q*_post _I*, fe robust
		outreg2 using ../out/emr-RF-$EDITION.xls, excel
	
		xtreg `lhv' payment_`denom'_Q*_post _I* if payment_`denom'<`windsor_`denom'', fe robust
		test payment_`denom'_post
		local fstat = r(F)
		outreg2 using ../out/emr-RF-$EDITION.xls, excel addtext(Windsor, "Windsor") 
		
	}
	
}
asdf
*/

	* 2SLS

local replace replace
foreach Xvar in emr_100 emr_any {
	
	foreach lhv in z_core z_mort z_read nrev_per_payroll nrev_per_fte admits_per_payroll admits_per_fte {
	
		xtivreg2 `lhv' (`Xvar' = qual_mcd_post) _I*, fe robust
		outreg2 using ../out/emr-2sls-$EDITION.xls, excel `replace' addtext(IV, "Qualifier", Windsor, "No")
		local replace
	
		xtivreg2 `lhv' (`Xvar' = payment_post) _I*, fe robust
		outreg2 using ../out/emr-2sls-$EDITION.xls, excel addtext(IV, "Prog. Pay", Windsor, "No")

		foreach denom in bed fte rev {
	
			xtivreg2 `lhv' (`Xvar' = payment_`denom'_post) _I*, fe robust
			outreg2 using ../out/emr-2sls-$EDITION.xls, excel addtext(IV, "Pay/`denom'", Windsor, "No")
	
			xtivreg2 `lhv' (`Xvar' = payment_`denom'_post) _I* if payment_`denom'<`windsor_`denom'', fe robust
			outreg2 using ../out/emr-2sls-$EDITION.xls, excel addtext(IV, "Pay/`denom'", Windsor, "Yes")
		}
	
	}
	
}

cap log close


