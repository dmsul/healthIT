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

global PLOT_STEM ../gph/plot-140212

**************************
**************************

use $IN_REGREADY, clear

 * Drop 2005, lots of missing hospitals
drop if year<2006


*******************
**	Basic plots
*******************
/*
preserve

keep if year==2010

hist beds_h, by(payment_bed_group, title("Density of Size by Pay/Bed Quartile") subtitle("Full sample"))
graph export $PLOT_STEM-hist-beds-full.png, width(2000) replace

twoway scatter payment beds_h, name(temp1) nodraw
binscatter payment beds_h, line(none) name(temp2) nodraw
twoway scatter payment_bed beds_h, name(temp3) nodraw
binscatter payment_bed beds_h, line(none) name(temp4) nodraw

graph combine temp1 temp2 temp3 temp4, ///
	title("Payments and Beds")
graph export $PLOT_STEM-summ-PayBeds.png, width(2000) replace






restore

*/

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
asdf
keep if meanbeds<=65 & maxbeds<100


 * SET CONTROL GROUP
if $CONTROL==1 {
	gen control = cpoe_from2007==1
	local control_var "cpoe_from2007"
}
else if $CONTROL==2 {
	gen control = basicn_from2008==1
	local control_var "basicn_from2008"
}
else if $CONTROL==3 {
	gen control = compreh_from2008==1
	local control_var "compreh_from2008"
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
	forval q=1/`quantiles' {
		gen `var'_Q`q'_post = (`var'_group==`q')*post if `var'<.
	}
	continue, break
}


*******************
**	Plots
*******************


	**	Hist of pay/bed by beds quartile **
/*
hist beds_h, by(payment_bed_group, title("Density of Size by Pay/Bed Quartile") subtitle("Small sample"))
graph export $PLOT_STEM-hist-beds-small.png, width(2000) replace
asdf
*/


gen count = 1

collapse (count) count (mean) live_* newadopt_* nomisscontract_* age_* recent_* our_compre* our_basic_notes agha_hit z_* nrev* lrev* beds_h, by(payment_bed_group year)

local var our_comprehensive

local mlabconfig "mlabel(payment_bed_group) mlabp(0) msize(medlarge) mc(white) mlabs(medlarge)"

/*
collapse (mean) `var' [fw=count], by(year)
twoway connected `var' year
asdf
*/


foreach var in live_cpoe our_basic_notes our_comprehensive z_core z_read z_mort /*lrev_fte lrev_payroll beds_h*/ {
	
	if inlist("`var'","live_cpoe", "our_basic_notes", "our_comprehensive") local axis = 2
	else local axis = 1


	qui summ year if `var'!=.
	local startyear = r(min)


	twoway  (connected `var' year if payment_bed_group==0, `mlabconfig' yaxis(`axis')) ///
			(connected `var' year if payment_bed_group==1, `mlabconfig' yaxis(1)) ///
			(connected `var' year if payment_bed_group==2, `mlabconfig' yaxis(1)) ///
			(connected `var' year if payment_bed_group==3, `mlabconfig' yaxis(1)) ///
			(connected `var' year if payment_bed_group==4, `mlabconfig' yaxis(1)) if year>=`startyear', ///
			ti("`var'") subtitle("`control_var'") leg(lab(1 "Control") lab(2 "1st Quartile, Pay/Bed") lab(3 "2nd Quartile, Pay/Bed") lab(4 "3rd Quartile, Pay/Bed") lab(5 "4th Quartile, Pay/Bed")) xlab(`startyear'/2011)

	graph export $PLOT_STEM-`control_var'-`var'.png, replace width(2000)
}



