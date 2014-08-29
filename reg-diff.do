/*
	Regressions using data from HospCompare and AHA.

	***Assume for EHR that 0 = no; 1 = partial, 2 = full, N = no
	
	
*/
set more off
clear all

global EDITION 2

global STARTYEAR 2005

local discharge_var aha_admits

if `1'==1 {
* SHORTEN HERE
use ../dta/himss_panel_full

bys uniqueid year: keep if hosp_id!=""


gen general = regexm(type,"General")
replace type = "General" if general==1
replace type = "Pedatric" if regexm(type,"edatric")
replace type = "Oncology" if regexm(type,"ncology")

gen usetag = inlist(type,"Oncology","General","Pediatric","Academic") & haentitytype=="Hospital"

keep hosp_id year usetag

duplicates drop

bys hosp_id year (usetag): drop if _n==1 & _N>1

bys hosp_id: egen maxuse = max(usetag)

keep hosp_id maxuse

duplicates drop

tempfile fullusetag
save `fullusetag'

use ../dta/hIT-combineddata, clear


* WHY to missing? [2/6/14]
replace beds_h = . if year==2007
replace paytot = . if year==2007

merge m:1 hosp_id using `fullusetag'

keep if maxuse==1 & _merge==3

drop if year<$STARTYEAR

tab year

cap drop temp*


replace post = year>=2011


*********************
**	Payment variables
*********************

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

ren payment_post payment__post

	* Gen payment yearly interactions
local start1 = $STARTYEAR + 1
foreach var in payment payment_bed payment_fte payment_rev {
	forval year = `start1'/2011 {
		gen `var'_y`year' = `var'*(year==`year')
		cap rename payment_y`year' payment__y`year'
	}
}




	* Windsorizing cutoffs
drop if payment>20	
drop if payment_bed>2

foreach var in rev bed fte {
	_pctile payment_`var', p(99)
	local windsor_`var' = r(r1)
}

	* Labor productivity variables
gen nrev_per_payroll = netoperrev/paytot
gen nrev_per_fte = (netoperrev/1e6)/ftetotal
gen admits_per_payroll = admh/(paytot/1e6)
gen admits_per_fte = admh/ftetotal


gen lrev_payroll = ln(nrev_per_payroll)
gen lrev_fte = ln(nrev_per_fte)
gen ladmit_payroll = ln(admits_per_payroll)
gen ladmit_fte = ln(admits_per_fte)


		* By quantiles
bys hosp_id: gen rep = _n==1

foreach var in payment_rev payment_bed payment_fte payment beds_h {
	bys id: egen temp_`var'1 = mean(`var') if year<2010
	bys id: egen temp_`var' = max(temp_`var'1)
	xtile temp1 = `var' if rep, n(4)
	bys id: egen `var'_group = max(temp1)
	summ `var'_group
	drop temp*
	forval q=2/4 {
		gen `var'_Q`q'_post = (`var'_group==`q')*post if `var'<.
	}
}


*********************
**	hIT variables
*********************

foreach var in cpoe cds data_repos emar {
	gen live_`var' = inlist(app_`var',1,2) if app_`var'!=.
}


gen our_basic = app_data_repos==1 & app_cpoe==1 if in_app==1
gen our_basic_notes = our_basic * (app_doc_doc==1) if in_app==1

gen our_certified = inlist(1,app_data_repos,app_cds,app_cpoe,app_doc_doc,app_nurs_doc,app_emar) if in_app==1


gen our_comprehensive = app_data_repos==1 & app_doc_doc==1 & app_nurs_doc==1 & app_cpoe==1 & app_cds==1 & app_emar==1 & pacs_imgdist==1 if in_app==1 & in_pacs==1
gen our_compre_2009 = our_comprehensive==1 & cdss_guide==1 & cdss_drug_int==1 & cdss_dose==1 if our_comprehensive!=. & in_cdss==1
gen our_compre_result = our_comprehensive==1 & inrange(comp_results,1,100) if our_comprehensive!=. & in_comp==1
gen our_compre_result2009 = our_comprehensive==1 & inrange(comp_results,1,100) & cdss_guide==1 & cdss_drug_int==1 & cdss_dose==1 if our_comprehensive!=. & in_cdss==1 & in_comp==1

gen agha_hit = inlist(app_cds,1,2,3,4) | inlist(app_ent_emr,1,2,3,4)



egen any_app = rowmin(app_*) if in_app==1
bys id any_app (year): gen temp = year[1] if any_app==1
bys id: egen first_app = max(temp)
drop temp*


		*** Contract year variables
		
summ contract_*

local EMRAPPS data_repos cds cpoe ent_emr order_entry doc_doc med_termin doc_portal nurs_doc lab_is emar
drop contract_oth app_oth

egen app_any = rowmin(app_*)

foreach var in `EMRAPPS' any {
	
	sort id year
	gen newadopt_`var' = app_`var'<=4 & l.app_`var'>4 if l.app_`var'<99

	if "`var'"=="any" egen contract_any = rowmax(contract_*)

		* Fill in obvious holes
	qui replace year = - year
			// This year says "past year", fill in past years
	if "`var'"!="any" bys id (year): replace contract_`var' = contract_`var'[_n-1] if contract_`var'[_n-1]<=abs(year) & app_`var'<=5 //& contract_`var'==. & 
	else bys id (year): replace contract_`var' = contract_`var'[_n-1] if contract_`var'[_n-1]<=abs(year) //& contract_`var'==.
	
			
	
	qui replace year = abs(year)
	
		* Calculate age of contract, fill in obvious holes
	gen age_`var' = year - contract_`var'
	
		* "Recent" flag
	gen recent_`var' = age_`var' ==1 if age_`var'!=.
	sort id year
	
	gen recent_`var'_1 = recent_`var'
	gen recent_`var'_2 = recent_`var'
	
	replace recent_`var'_1 = 0 if inlist(app_`var',5,6,7) & app_`var'!=.
	replace recent_`var'_2 = 1 if newadopt_`var'==1
	
	egen recent_`var'_3 = rowmax(recent_`var'_*)
	
	
	
		* Missing flags
	bys id: egen temp = count(contract_`var') if year<=2009
	gen temp2 = temp>0 & temp<.
	bys id: egen hasanyprecontract_`var' = max(temp2)
	
	gen nomisscontract_`var' = contract_`var'!=.
	
	drop temp*
}

gen recent_imgdist = pacs_img==1 & l.pacs_img!=1


local rflag _3

*	Recent upgrades to composite EHR variables

egen recent_basic = rowmax(recent_data_repos`rflag' recent_cpoe`rflag') if in_app==1
egen recent_basic_notes = rowmax(recent_data_repos`rflag' recent_cpoe`rflag' recent_doc_doc`rflag') if in_app==1

egen recent_certified = rowmax(recent_data_repos`rflag' recent_cds`rflag' recent_cpoe`rflag' recent_doc_doc`rflag' recent_nurs_doc`rflag' recent_emar`rflag') if in_app==1


egen recent_comprehensive = rowmax(recent_data_repos`rflag' recent_cpoe`rflag' recent_doc_doc`rflag' recent_nurs_doc`rflag' recent_cds`rflag' recent_emar`rflag' recent_imgdist) if in_app==1 & in_pacs==1

*gen our_compre_2009 = our_comprehensive==1 & cdss_guide==1 & cdss_drug_int==1 & cdss_dose==1 if our_comprehensive!=. & in_cdss==1
*gen our_compre_result = our_comprehensive==1 & inrange(comp_results,1,100) if our_comprehensive!=. & in_comp==1
*gen our_compre_result2009 = our_comprehensive==1 & inrange(comp_results,1,100) & cdss_guide==1 & cdss_drug_int==1 & cdss_dose==1 if our_comprehensive!=. & in_cdss==1 & in_comp==1

*gen agha_hit = inlist(app_cds,1,2,3,4) | inlist(app_ent_emr,1,2,3,4)

gen recent_b2 = recent_basic_note
replace recent_b2 = 0 if recent_basic_note==. & our_basic_note==0

*/
gen group = payment_bed_group
save ../dta/temp_regready, replace
asdf
}	// End `i' if statement



use ../dta/temp_regready, clear
drop if year==2005  // Many 4th quartile firms missing this year


if `1'==3 asdf

xi i.year

*******************
**	Plots
*******************

gen count = 1

if `1'==0 {

collapse (count) count (mean) live_* newadopt_* nomisscontract_* age_* recent_* our_compre* our_basic_notes agha_hit z_* nrev* lrev* beds_h, by(payment_bed_group year)

local var lrev_payroll

local mlabconfig "mlabel(payment_bed_group) mlabp(0) msize(medlarge) mc(white) mlabs(medlarge)"

/*
collapse (mean) `var' [fw=count], by(year)
twoway connected `var' year
asdf
*/


foreach var in recent_any_3 recent_cpoe_3 recent_b2 recent_cds_3 recent_compreh recent_basic_note live_cpoe live_cds live_emar newadopt_cpoe newadopt_cds newadopt_emar { // our_basic_notes our_comprehensive our_compre_result agha_hit z_core z_read z_mort lrev_fte lrev_payroll beds_h {


	qui summ year if `var'!=.
	local startyear = r(min)


	twoway  (connected `var' year if payment_bed_group==1, `mlabconfig') ///
			(connected `var' year if payment_bed_group==2, `mlabconfig') ///
			(connected `var' year if payment_bed_group==3, `mlabconfig') ///
			(connected `var' year if payment_bed_group==4, `mlabconfig') if year>=`startyear', ///
			ti("`var'") leg(lab(1 "1st Quartile, Pay/Bed") lab(2 "2nd Quartile, Pay/Bed") lab(3 "3rd Quartile, Pay/Bed") lab(4 "4th Quartile, Pay/Bed")) xlab(`startyear'/2011)
		
	graph export ../gph/mtg1220-plot-`var'.png, replace
	
	
}

asdf
}
*/



*******************
**	Regressions
*******************

if `1'==2 {
*/


			*** 	1st Stage

sort id year

* TEMP

xtreg our_basic_notes payment_bed_post i.year, fe robust
outreg2 using ../out/mtg1220-regs.xls, excel replace
xtreg our_basic_notes payment_bed_Q*_post i.year if payment_bed_group<., fe robust
outreg2 using ../out/mtg1220-regs.xls, excel

xtreg d.our_basic_notes payment_bed_post i.year, fe robust
outreg2 using ../out/mtg1220-regs.xls, excel
xtreg d.our_basic_notes payment_bed_Q*_post i.year if payment_bed_group<., fe robust
outreg2 using ../out/mtg1220-regs.xls, excel

xtreg our_comprehensive payment_bed_post i.year, fe robust
outreg2 using ../out/mtg1220-regs.xls, excel
xtreg our_comprehensive payment_bed_Q*_post i.year if payment_bed_group<., fe robust
outreg2 using ../out/mtg1220-regs.xls, excel

xtreg d.our_comprehensive payment_bed_post i.year, fe robust
outreg2 using ../out/mtg1220-regs.xls, excel
xtreg d.our_comprehensive payment_bed_Q*_post i.year if payment_bed_group<., fe robust
outreg2 using ../out/mtg1220-regs.xls, excel

xtreg recent_basic_notes payment_bed_post i.year, fe robust
outreg2 using ../out/mtg1220-regs.xls, excel
xtreg recent_basic_notes payment_bed_Q*_post i.year if payment_bed_group<., fe robust
outreg2 using ../out/mtg1220-regs.xls, excel

xtreg recent_comprehensive payment_bed_post i.year, fe robust
outreg2 using ../out/mtg1220-regs.xls, excel
xtreg recent_comprehensive payment_bed_Q*_post i.year if payment_bed_group<., fe robust
outreg2 using ../out/mtg1220-regs.xls, excel

xtreg recent_cpoe payment_bed_post i.year, fe robust
outreg2 using ../out/mtg1220-regs.xls, excel
xtreg recent_cpoe payment_bed_Q*_post i.year if payment_bed_group<., fe robust
outreg2 using ../out/mtg1220-regs.xls, excel

xtreg recent_cpoe payment_bed_post i.year, fe robust
outreg2 using ../out/mtg1220-regs.xls, excel
xtreg recent_cpoe payment_bed_Q*_post i.year if payment_bed_group<., fe robust
outreg2 using ../out/mtg1220-regs.xls, excel

xtreg live_cpoe payment_bed_post i.year, fe robust
outreg2 using ../out/mtg1220-regs.xls, excel
xtreg live_cpoe payment_bed_Q*_post i.year if payment_bed_group<., fe robust
outreg2 using ../out/mtg1220-regs.xls, excel

xtreg d.live_cpoe payment_bed_post i.year, fe robust
outreg2 using ../out/mtg1220-regs.xls, excel
xtreg d.live_cpoe payment_bed_Q*_post i.year if payment_bed_group<., fe robust
outreg2 using ../out/mtg1220-regs.xls, excel


xtreg z_core payment_bed_post i.year if payment_bed_group<., fe robust
outreg2 using ../out/mtg1220-regs.xls, excel
xtreg z_core payment_bed_Q*_post i.year if payment_bed_group<., fe robust
outreg2 using ../out/mtg1220-regs.xls, excel
xtreg d.z_core payment_bed_post i.year if payment_bed_group<., fe robust
outreg2 using ../out/mtg1220-regs.xls, excel
xtreg d.z_core payment_bed_Q*_post i.year if payment_bed_group<., fe robust
outreg2 using ../out/mtg1220-regs.xls, excel

xtreg z_mort payment_bed_post i.year if payment_bed_group<., fe robust
outreg2 using ../out/mtg1220-regs.xls, excel
xtreg z_mort payment_bed_Q*_post i.year if payment_bed_group<., fe robust
outreg2 using ../out/mtg1220-regs.xls, excel
xtreg d.z_mort payment_bed_post i.year if payment_bed_group<., fe robust
outreg2 using ../out/mtg1220-regs.xls, excel
xtreg d.z_mort payment_bed_Q*_post i.year if payment_bed_group<., fe robust
outreg2 using ../out/mtg1220-regs.xls, excel

xtreg z_read payment_bed_post i.year if payment_bed_group<., fe robust
outreg2 using ../out/mtg1220-regs.xls, excel
xtreg z_read payment_bed_Q*_post i.year if payment_bed_group<., fe robust
outreg2 using ../out/mtg1220-regs.xls, excel
xtreg d.z_read payment_bed_post i.year if payment_bed_group<., fe robust
outreg2 using ../out/mtg1220-regs.xls, excel
xtreg d.z_read payment_bed_Q*_post i.year if payment_bed_group<., fe robust
outreg2 using ../out/mtg1220-regs.xls, excel

xtreg lrev_fte payment_bed_post i.year if payment_bed_group<., fe robust
outreg2 using ../out/mtg1220-regs.xls, excel
xtreg lrev_fte payment_bed_Q*_post i.year if payment_bed_group<., fe robust
outreg2 using ../out/mtg1220-regs.xls, excel
xtreg d.lrev_fte payment_bed_post i.year if payment_bed_group<., fe robust
outreg2 using ../out/mtg1220-regs.xls, excel
xtreg d.lrev_fte payment_bed_Q*_post i.year if payment_bed_group<., fe robust
outreg2 using ../out/mtg1220-regs.xls, excel

xtreg lrev_payroll payment_bed_post i.year if payment_bed_group<., fe robust
outreg2 using ../out/mtg1220-regs.xls, excel
xtreg lrev_payroll payment_bed_Q*_post i.year if payment_bed_group<., fe robust
outreg2 using ../out/mtg1220-regs.xls, excel
xtreg d.lrev_payroll payment_bed_post i.year if payment_bed_group<., fe robust
outreg2 using ../out/mtg1220-regs.xls, excel
xtreg d.lrev_payroll payment_bed_Q*_post i.year if payment_bed_group<., fe robust
outreg2 using ../out/mtg1220-regs.xls, excel

xtreg ladmit_fte payment_bed_post i.year if payment_bed_group<., fe robust
outreg2 using ../out/mtg1220-regs.xls, excel
xtreg ladmit_fte payment_bed_Q*_post i.year if payment_bed_group<., fe robust
outreg2 using ../out/mtg1220-regs.xls, excel
xtreg d.ladmit_fte payment_bed_post i.year if payment_bed_group<., fe robust
outreg2 using ../out/mtg1220-regs.xls, excel
xtreg d.ladmit_fte payment_bed_Q*_post i.year if payment_bed_group<., fe robust
outreg2 using ../out/mtg1220-regs.xls, excel

xtreg ladmit_payroll payment_bed_post i.year if payment_bed_group<., fe robust
outreg2 using ../out/mtg1220-regs.xls, excel
xtreg ladmit_payroll payment_bed_Q*_post i.year if payment_bed_group<., fe robust
outreg2 using ../out/mtg1220-regs.xls, excel
xtreg d.ladmit_payroll payment_bed_post i.year if payment_bed_group<., fe robust
outreg2 using ../out/mtg1220-regs.xls, excel
xtreg d.ladmit_payroll payment_bed_Q*_post i.year if payment_bed_group<., fe robust
outreg2 using ../out/mtg1220-regs.xls, excel


/*
asdf
*/
gen Z = (payment_bed_group==4 & post==1) if payment_bed_group<.

xtreg recent_any payment_bed_Q*_post i.year, fe robust
testparm payment_bed_Q*_post
xtivreg d.z_core (recent_any = payment_bed_Q*_post) i.year if payment_bed_group<., fe
asdf
/*
asdf

xtivreg d.z_mort (d.our_comprehensive = Z) beds_h  i.year if payment_bed_group<., fe 
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

