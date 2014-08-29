/*
	Regressions using data from HospCompare and AHA.

	***Assume for EHR that 0 = no; 1 = partial, 2 = full, N = no
	
	
*/
set more off
clear all

global EDITION 2

global STARTYEAR 2005

local discharge_var aha_admits

global CONTROL = 0

**************************
**		I/O
**************************

global IN_REGREADY ../dta/hIT-regready

global OUTREG_STEM ../out/regs-140212-cont$CONTROL.xls


*******************
*******************


use $IN_REGREADY, clear


*******************
**	Sample restriction
*******************


 * Indicators for "had IT from year X"
foreach year in 2006 2007 2008 2009 {
	bys id: egen temp1 = min(live_cpoe) if year>=`year'
	bys id: egen cpoe_from`year' = min(temp1)
	
	bys id: egen temp2 = min(our_basic_notes) if year>=`year'
	bys id: egen basicn_from`year' = min(temp2)
	
	bys id: egen temp3 = min(our_comprehensive) if year>=`year'
	bys id: egen compreh_from`year' = min(temp3)
	
	drop temp*
}
order id year cpoe_from* basicn_from* compreh_from*


 * Keep 1st quartile of beds distribution, drop those with large fluctuations
bys id: egen meanbeds = mean(beds_h)
bys id: egen maxbeds = max(beds_h)
keep if meanbeds<=65 & maxbeds<100


 * SET CONTROL GROUP
if $CONTROL==1 {
	gen control = cpoe_from2007==1
	local control_var "cpoe_from2007"
	drop if year<2007
}
else if $CONTROL==2 {
	gen control = basicn_from2008==1
	local control_var "basicn_from2008"
	drop if year<2008
}
else if $CONTROL==3 {
	gen control = compreh_from2008==1
	local control_var "compreh_from2008"
	drop if year<2008
}
else if $CONTROL==0 {
	gen control = 0
	local control_var "non"
	drop if year<2007
}




		* (Re)-Create treatment-by-quantile

cap drop payment*group payment*Q*

local quantiles = 4
cap drop rep
bys hosp_id: gen rep = _n==_N

foreach var in payment_bed payment_rev payment_fte payment beds_h {
	bys id: egen temp_`var'1 = mean(`var') if year<2010
	bys id: egen temp_`var' = max(temp_`var'1)
	xtile temp1 = `var' if rep==1 & control==0, n(`quantiles')
	bys id: egen `var'_group = max(temp1)
	replace `var'_group = 0 if control==1
	summ `var'_group
	drop temp*
	forval q=2/`quantiles' {
		gen `var'_Q`q'_post = (`var'_group==`q')*post if `var'<.
	}
	continue, break
}
replace payment_bed_post = 0 if control==1



*******************
**	Regressions
*******************

			*** 	1st Stage

sort id year

* TEMP

local replace replace
qui{
if $CONTROL==1 {
	xtreg live_cpoe payment_bed_post i.year, fe robust
	outreg2 using $OUTREG_STEM, excel `replace'
	xtreg live_cpoe payment_bed_Q*_post i.year if payment_bed_group<., fe robust
	outreg2 using $OUTREG_STEM, excel
	xtreg d.live_cpoe payment_bed_post i.year, fe robust
	outreg2 using $OUTREG_STEM, excel
	xtreg d.live_cpoe payment_bed_Q*_post i.year if payment_bed_group<., fe robust
	outreg2 using $OUTREG_STEM, excel
	local replace
}

if $CONTROL<=2 {

	xtreg our_basic_notes payment_bed_post i.year, fe robust
	outreg2 using $OUTREG_STEM, excel `replace'
	xtreg our_basic_notes payment_bed_Q*_post i.year if payment_bed_group<., fe robust
	outreg2 using $OUTREG_STEM, excel

	xtreg d.our_basic_notes payment_bed_post i.year, fe robust
	outreg2 using $OUTREG_STEM, excel
	xtreg d.our_basic_notes payment_bed_Q*_post i.year if payment_bed_group<., fe robust
	outreg2 using $OUTREG_STEM, excel
	local replace
}

xtreg our_comprehensive payment_bed_post i.year, fe robust
outreg2 using $OUTREG_STEM, excel
xtreg our_comprehensive payment_bed_Q*_post i.year if payment_bed_group<., fe robust
outreg2 using $OUTREG_STEM, excel

xtreg d.our_comprehensive payment_bed_post i.year, fe robust
outreg2 using $OUTREG_STEM, excel
xtreg d.our_comprehensive payment_bed_Q*_post i.year if payment_bed_group<., fe robust
outreg2 using $OUTREG_STEM, excel

xtreg z_core payment_bed_post i.year if payment_bed_group<., fe robust
outreg2 using $OUTREG_STEM, excel
xtreg z_core payment_bed_Q*_post i.year if payment_bed_group<., fe robust
outreg2 using $OUTREG_STEM, excel
xtreg d.z_core payment_bed_post i.year if payment_bed_group<., fe robust
outreg2 using $OUTREG_STEM, excel
xtreg d.z_core payment_bed_Q*_post i.year if payment_bed_group<., fe robust
outreg2 using $OUTREG_STEM, excel

xtreg z_mort payment_bed_post i.year if payment_bed_group<., fe robust
outreg2 using $OUTREG_STEM, excel
xtreg z_mort payment_bed_Q*_post i.year if payment_bed_group<., fe robust
outreg2 using $OUTREG_STEM, excel
xtreg d.z_mort payment_bed_post i.year if payment_bed_group<., fe robust
outreg2 using $OUTREG_STEM, excel
xtreg d.z_mort payment_bed_Q*_post i.year if payment_bed_group<., fe robust
outreg2 using $OUTREG_STEM, excel

xtreg z_read payment_bed_post i.year if payment_bed_group<., fe robust
outreg2 using $OUTREG_STEM, excel
xtreg z_read payment_bed_Q*_post i.year if payment_bed_group<., fe robust
outreg2 using $OUTREG_STEM, excel
xtreg d.z_read payment_bed_post i.year if payment_bed_group<., fe robust
outreg2 using $OUTREG_STEM, excel
xtreg d.z_read payment_bed_Q*_post i.year if payment_bed_group<., fe robust
outreg2 using $OUTREG_STEM, excel
}


asdf

xtivreg d.z_mort (d.our_comprehensive = Z) i.year if payment_bed_group<., fe 
xtivreg d.z_read (d.our_comprehensive = Z) beds_h  i.year if payment_bed_group<., fe 
xtivreg d.lrev_fte (d.our_comprehensive = Z) beds_h  i.year if payment_bed_group<., fe 
xtivreg d.lrev_payroll (d.our_comprehensive = Z) beds_h  i.year if payment_bed_group<., fe 
xtivreg d.ladmit_fte (d.our_comprehensive = Z) beds_h i.year if payment_bed_group<., fe 
xtivreg d.ladmit_payroll (d.our_comprehensive = Z) beds_h i.year if payment_bed_group<., fe 

asdf
*/

xtreg agha_hit payment_bed_Q*_post i.year if payment_bed_group<., fe robust

		
xtreg recent payment_bed_Q*_post i.year if payment_bed_group<. & hasage_cds==1, fe robust

xtreg age_cds payment_bed_Q*_post i.year if payment_bed_group<. & hasage_cds==1, fe robust


xtreg d.recent payment_bed_Q*_post i.year if payment_bed_group<. & hasage_cds==1, fe robust

*/


asdf
}		

