/*
	Regressions using data from HospCompare and AHA.

	***Assume for EHR that 0 = no; 1 = partial, 2 = full, N = no
	
	
*/

global DATA_EDITION 130723
global EDITION 130812

local discharge_var aha_admits


set more off
clear all

use ../dta/hIT-combineddata

cap drop temp*

bys id: gen rep = _n==1


foreach var in qual_mcd qual_mcr sh10 {
	gen `var'_post = `var'*post
}

gen qual_both = qual_mcr*qual_mcd
gen qual_both_post = qual_both*post

gen bene_post = bene_tot*post
bys id: egen mrev = mean(netoperrev)

gen bene_rev = bene_tot/netoperr_09
gen bene_beds = bene_tot/beds_h_09
gen bene_fte = bene_tot/(ftetotal_09*1e6)


gen bene_mcr_post = bene_mcr*post/1e6
gen bene_mcd_post = bene_mcd*post/1e6

gen bene_mcr_rev_post = post*bene_mcr/mrev
gen bene_mcd_rev_post = post*bene_mcd/mrev


replace bene_post = bene_post/1e6

forval year=2009/2011 {
	gen bene_y`year' = bene_tot*(year==`year')/1e6
	gene bene_rev_y`year' = bene_rev*(year==`year')
}



*******************
**	Regressions
*******************


local replace replace

* 1st Stage - State program launch/firstpay IV
local lhv z_core

cap log close
log using ../out/reg-DD-130812-log.txt, replace


local replace replace
foreach lhv in emr_any emr_geq50 z_core z_mort z_read netr_per_pay netr_per_fte {

	xtreg `lhv' qual_mcd_post _I*, fe robust
	outreg2 using ../out/emr-1stRF-$EDITION.xls, excel `replace' 
	local replace
	
	xtreg `lhv' bene_mcr_post _I*, fe robust
	outreg2 using ../out/emr-1stRF-$EDITION.xls, excel 

	xtreg `lhv' bene_mcd_post _I*, fe robust
	outreg2 using ../out/emr-1stRF-$EDITION.xls, excel 

	xtreg `lhv' bene_mcd_post bene_mcr_post _I*, fe robust
	outreg2 using ../out/emr-1stRF-$EDITION.xls, excel
	
	xtreg `lhv' bene_mcr_rev_post _I*, fe robust
	outreg2 using ../out/emr-1stRF-$EDITION.xls, excel 

	xtreg `lhv' bene_mcd_rev_post _I* if bene_rev<5, fe robust
	outreg2 using ../out/emr-1stRF-$EDITION.xls, excel cttop(Windsor)
	
	xtreg `lhv' bene_mcr_rev_post _I* if bene_rev<5, fe robust
	outreg2 using ../out/emr-1stRF-$EDITION.xls, excel cttop(Windsor)

	xtreg `lhv' bene_mcd_rev_post _I*, fe robust
	outreg2 using ../out/emr-1stRF-$EDITION.xls, excel 
		
	xtreg `lhv' bene_post _I*, fe robust
	outreg2 using ../out/emr-1stRF-$EDITION.xls, excel 

	xtreg `lhv' bene_rev_post _I*, fe robust
	outreg2 using ../out/emr-1stRF-$EDITION.xls, excel 
	
	xtreg `lhv' bene_rev_post _I* if bene_rev<5, fe robust
	outreg2 using ../out/emr-1stRF-$EDITION.xls, excel cttop(Windsor)
	
}


local replace replace
foreach lhv in z_core z_mort z_read netr_per_pay netr_per_fte {

	xtivreg2 `lhv' (emr_any = qual_mcd_post) _I*, fe robust
	outreg2 using ../out/emr-2sls-$EDITION.xls, excel `replace' cttop(qual_mcd_post)
	local replace
	
	xtivreg2 `lhv' (emr_any = bene_mcr_post) _I*, fe robust
	outreg2 using ../out/emr-2sls-$EDITION.xls, excel cttop(bene_mcr_post)

	xtivreg2 `lhv' (emr_any = bene_mcd_post) _I*, fe robust
	outreg2 using ../out/emr-2sls-$EDITION.xls, excel cttop(bene_mcd_post)

	xtivreg2 `lhv' (emr_any = bene_mcd_post bene_mcr_post) _I*, fe robust
	outreg2 using ../out/emr-2sls-$EDITION.xls, excel cttop(both bene)
	
	xtivreg2 `lhv' (emr_any = bene_mcr_rev_post) _I*, fe robust
	outreg2 using ../out/emr-2sls-$EDITION.xls, excel cttop(bene_mcr_rev_post)

	xtivreg2 `lhv' (emr_any = bene_mcd_rev_post) _I*, fe robust
	outreg2 using ../out/emr-2sls-$EDITION.xls, excel cttop(bene_mcd_rev_post)
	
	xtivreg2 `lhv' (emr_any = bene_mcr_rev_post) _I* if bene_rev<5,  fe robust
	outreg2 using ../out/emr-2sls-$EDITION.xls, excel cttop(Windsor, mcr)

	xtivreg2 `lhv' (emr_any = bene_mcd_rev_post) _I* if bene_rev<5, fe robust
	outreg2 using ../out/emr-2sls-$EDITION.xls, excel cttop(Windsor, mcd)
		
	xtivreg2 `lhv' (emr_any = bene_post) _I*, fe robust
	outreg2 using ../out/emr-2sls-$EDITION.xls, excel cttop(bene_post)

	xtivreg2 `lhv' (emr_any = bene_rev_post) _I*, fe robust
	outreg2 using ../out/emr-2sls-$EDITION.xls, excel cttop(bene_rev_post)
	
	xtivreg2 `lhv' (emr_any = bene_rev_post) _I* if bene_rev<5, fe robust
	outreg2 using ../out/emr-2sls-$EDITION.xls, excel cttop(Windsor, both)
	
}

cap log close


