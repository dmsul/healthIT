
**************************
**		I/O
**************************

global IN_REGREADY ../dta/hIT-regready

*******************


use $IN_REGREADY, clear

*******************
**	Sample restriction
*******************

 * Dummies: "always had" and "never had"
foreach year in 2007 2008 {
	bys id: egen min1 = min(live_cpoe) if year>=`year'
	bys id: egen max1 = max(live_cpoe) if year>=`year'
	bys id: egen cpoe_min`year' = min(min1)
	bys id: egen cpoe_max`year' = max(max1)
	
	
	bys id: egen min2 = min(our_basic_notes) if year>=`year'
	bys id: egen max2 = max(our_basic_notes) if year>=`year'
	bys id: egen basicn_min`year' = min(min2)
	bys id: egen basicn_max`year' = max(max2)
	
	bys id: egen min3 = min(our_comprehensive) if year>=`year'
	bys id: egen max3 = max(our_comprehensive) if year>=`year'
	bys id: egen compreh_min`year' = min(min3)
	bys id: egen compreh_max`year' = max(max3)
	
	drop min* max*
}

order id year cpoe_min* basicn_min* compreh_min*


 * Drop hosp w/ large beds changes
bys id: egen medbeds = median(beds_h)
bys id: egen maxbeds = max(beds_h)
drop if maxbeds/medbeds>1.30 & maxbeds - medbeds>20

cap drop rep
bys id: gen rep = _n==1
summ medbeds if rep==1, d

 * Size Bins
gen small = medbeds <=65
gen large = medbeds > 275 & medbeds<.
gen medium =!small & !large & medbeds<.
gen size = small + 2*medium + 3*large

lab def sizes 1 "small" 2 "medium" 3 "large"
lab values size sizes

 * SET CONTROL GROUP
if $CONTROL==1 {
	gen always = cpoe_min2007==1
	gen never = cpoe_max2007==0
	global control_var "cpoe2007"
	drop if year<2007
}
else if $CONTROL==2 {
	gen always = basicn_min2008==1
	gen never = basicn_max2008==0
	global control_var "basicn2008"
	drop if year<2008
}
else if $CONTROL==3 {
	gen always = compreh_min2008==1
	gen never = compreh_max2008==0
	global control_var "compreh2008"
	drop if year<2008
}
else if $CONTROL==0 {
	gen always = 0
	gen never = 0
	global control_var "none"
	drop if year<2007
}

gen adopter = always==0 & never==0

cap drop takeup
gen takeup = -1*never + always
label def takers -1 "Never" 0 "Adopters" 1 "Always"
label values takeup takers

label var live_cpoe "Live CPOE"
label var our_basic_notes "BasicN"
label var our_comprehensive "Comprehensive"


/*
		* (Re)-Create treatment-by-quantile

cap drop payment*group payment*Q*

local quantiles = 4
cap drop rep
bys hosp_id: gen rep = _n==_N

foreach var in payment_bed payment_rev payment_fte payment beds_h {
	bys id: egen temp_`var'1 = mean(`var') if year<2010
	bys id: egen temp_`var' = max(temp_`var'1)
	xtile min1 = `var' if rep==1 & always==0, n(`quantiles')
	bys id: egen `var'_group = max(min1)
	replace `var'_group = 0 if always==1
	summ `var'_group
	drop temp*
	forval q=2/`quantiles' {
		gen `var'_Q`q'_post = (`var'_group==`q')*post if `var'<.
	}
	continue, break
}
replace payment_bed_post = 0 if always==1
*/

