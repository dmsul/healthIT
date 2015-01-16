/*
    This file does minor cleaning and sample restriction immediately prior to
    regressions/plots.
*/

set more off
clear all

run src/globals

* I/O
*--------

global IN_HIMSS_PANEL $himss_panel

global IN_COMBO_PANEL $combined_dta

global OUT_REGREADY $regready_dta

* Parameters
*-----------
// First year of sample
global STARTYEAR 2005
// Which proxy variable for # of discharges
local discharge_var aha_admits
// When does "post" treatment period begin?
global BEGIN_POST = 2011


* Prep other files
*------------------

    ***  Gen tag for appropriate hospital types    ***

use $IN_HIMSS_PANEL, clear

    * Drop if missing merge ID
bys uniqueid year: keep if hosp_id!=""

    * Account for variations in spelling
gen general = regexm(type,"General")
replace type = "General" if general==1
replace type = "Pedatric" if regexm(type,"edatric")
replace type = "Oncology" if regexm(type,"ncology")

    * Tag for relevant hosp types
gen usetag = inlist(type,"Oncology","General","Pediatric","Academic") & haentitytype=="Hospital"

    * Make hosp_id unique ID
keep hosp_id year usetag
duplicates drop
bys hosp_id year (usetag): drop if _n==1 & _N>1

    * Use the hosp if it ever has right 'type'
bys hosp_id: egen maxuse = max(usetag)

keep hosp_id maxuse
ren maxuse usetag
duplicates drop
tempfile fullusetag
save `fullusetag'


* MAIN
*--------

use $IN_COMBO_PANEL, clear


* WHY to missing? [2/6/14]            XXXXX
replace beds_h = . if year==2007
replace paytot = . if year==2007

merge m:1 hosp_id using `fullusetag', keep(3) nogen

    * Restrict to relevant hosp types
keep if usetag==1
drop usetag

    * Restrict sample years
drop if year<$STARTYEAR

tab year

cap drop temp*

    * Define post period
replace post = year>=$BEGIN_POST


*********************
**    CMS Program Payment variables
*********************

    * Change units to millions
gen payment = bene_tot/1e6

    * Norm benefits by some hospital size metrics
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

    * Gen "post" interactions
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


    * Windsorize
foreach var in rev bed fte {
    _pctile payment_`var', p(99)
    local windsor_`var' = r(r1)
}
drop if payment>20    
drop if payment_bed>2


    * Labor productivity variables
gen nrev_per_payroll = netoperrev/paytot
gen nrev_per_fte = (netoperrev/1e6)/ftetotal
gen admits_per_payroll = admh/(paytot/1e6)
gen admits_per_fte = admh/ftetotal


gen lrev_payroll = ln(nrev_per_payroll)
gen lrev_fte = ln(nrev_per_fte)
gen ladmit_payroll = ln(admits_per_payroll)
gen ladmit_fte = ln(admits_per_fte)


        * Create treatment-by-quantile
local quantiles = 4
        
bys hosp_id: gen rep = _n==1

foreach var in payment_rev payment_bed payment_fte payment beds_h {
    bys id: egen temp_`var'1 = mean(`var') if year<2010
    bys id: egen temp_`var' = max(temp_`var'1)
    xtile temp1 = `var' if rep, n(`quantiles')
    bys id: egen `var'_group = max(temp1)
    summ `var'_group
    drop temp*
    forval q=2/`quantiles' {
        gen `var'_Q`q'_post = (`var'_group==`q')*post if `var'<.
    }
}


*********************
**    hIT variables
*********************

* Each software type is 'live' this year
foreach var in cpoe cds data_repos emar {
    gen live_`var' = inlist(app_`var', 1, 2) if app_`var'!=.
}

*  Define our versions of IT uptake (least to most restrictive)
/*
ONC Data Brief (March 2013) definitions, see Table 2:
"certified"
    "meeting some or all MU objectives."
"basic"
    Patient demogs, problem lists, med lists, discharge summaries, CPOE:
    medications; view: lab reports, radiology reports, diagnostic tests;
"basic w notes"
    "basic", plus physician notes, nursing assessments
"comprehensive"
    "b w notes", plus 'advance directives', CPOE: lab reports, radiology,
    consult requests, nursing orders; view: radiology images, diag test images,
    consult reports

 */
gen our_certified = inlist(1, app_data_repos, app_cds, app_cpoe, app_doc_doc, ///
                           app_nurs_doc, app_emar) if in_app==1

gen our_basic =         app_data_repos==1 & ///
                        app_cpoe==1 ///
                        if in_app==1
gen our_basic_notes =   our_basic * (app_doc_doc==1) if in_app==1


gen our_comprehensive = app_data_repos == 1 & ///
                        app_doc_doc == 1 & ///
                        app_nurs_doc == 1 & ///
                        app_cpoe == 1 & ///
                        app_cds == 1 & ///
                        app_emar == 1 & ///
                        pacs_imgdist == 1 ///
                        if in_app == 1 & in_pacs == 1

/* CDSS variables only begin in 2009 */
gen our_compre_2009 =   our_comprehensive == 1 & ///
                        cdss_guide == 1 & ///
                        cdss_drug_int == 1 & ///
                        cdss_dose == 1 ///
                        if our_comprehensive != . & in_cdss == 1
/* Some other coverage problem with 'result' */
gen our_compre_result = our_comprehensive == 1 & ///
                        inrange(comp_results, 1, 100) ///
                        if our_comprehensive != . & in_comp == 1

gen our_compre_result2009 = our_comprehensive == 1 & ///
                            inrange(comp_results, 1, 100) & ///
                            cdss_guide == 1 & ///
                            cdss_drug_int == 1 & ///
                            cdss_dose == 1 ///
                            if our_comprehensive!=. & in_cdss == 1 & in_comp == 1

/* Replication of Agha (J Health Econ?, 2013 or 14) paper */
gen agha_hit = inlist(app_cds,1,2,3,4) | inlist(app_ent_emr,1,2,3,4)


egen any_app = rowmin(app_*) if in_app==1
bys id any_app (year): gen temp = year[1] if any_app==1
bys id: egen first_app = max(temp)
drop temp*


    ***     Contract year variables        ***
        
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
    
        * "Recent" flag (software is new)
    gen recent_`var' = age_`var' <=1 if age_`var'!=.
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


    * 
local rflag _3

*    Recent upgrades to composite EHR variables

egen recent_basic = rowmax(recent_data_repos`rflag' recent_cpoe`rflag') if in_app==1
egen recent_basic_notes = rowmax(recent_data_repos`rflag' recent_cpoe`rflag' recent_doc_doc`rflag') if in_app==1

egen recent_certified = rowmax(recent_data_repos`rflag' recent_cds`rflag' recent_cpoe`rflag' recent_doc_doc`rflag' recent_nurs_doc`rflag' recent_emar`rflag') if in_app==1


egen recent_comprehensive = rowmax(recent_data_repos`rflag' recent_cpoe`rflag' recent_doc_doc`rflag' recent_nurs_doc`rflag' recent_cds`rflag' recent_emar`rflag' recent_imgdist) if in_app==1 & in_pacs==1


gen recent_b2 = recent_basic_note
replace recent_b2 = 0 if recent_basic_note==. & our_basic_note==0

*/
gen group = payment_bed_group


* Employment Variables
*---------------------

egen tot_docs_pr = rowtotal(tetot tctot tgtot netot)
foreach yr in 2010 2011 {
    gen temp = (tetot + tctot + tgtot) / tot_docs_pr if year == `yr'
    bys hosp_id: egen frac_mdemp_`yr' = max(temp)
    drop temp
}


save $OUT_REGREADY, replace


