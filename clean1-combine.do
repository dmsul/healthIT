set trace off
set more off

run src/globals

* I/O
*-------
global IN_AHA $aha_clean_dta
global IN_HIMSS $himss_extract
global IN_COMPARE_CORE $hcompare_coremsr_dta
global IN_COMPARE_MORT $hcompare_mortality_dta
global IN_EHRPROG $ehr_progpayments_dta

global OUT_COMBINED $combined_dta


* MAIN
*-------

/*
import excel using "$DATA_PATH/source/MedicaidEHRStateLaunch.xls", clear
ren A state
ren B launchmo
ren C launchyr
ren D firstpaymo
ren E firstpayyr
ren F MUattestmo
ren G MUattestyr

foreach var of varlist *yr {
    replace `var' = `var'+2000
}

foreach var in launch firstpay MUattest {
    gen `var' = `var'yr + (`var'mo - 1)/12
}

tempfile stateprogs
save `stateprogs'
*/

clear all

/*
*run clean0-hcompare-core
*run clean0-hcompare-mort
*run clean0-EHRprogram
*run clean0-aha
*run clean0-himss
*/

use $IN_HIMSS

drop if hosp_id=="" // Need to fix this.

**** Combine datasets
merge 1:1 hosp_id year using $IN_COMPARE_MORT
drop if _merge==2
rename _merge _m_mortality

merge 1:1 hosp_id year using $IN_COMPARE_CORE
drop if _merge==2
rename _merge _m_coremsr

/* XXX [1/15/15] 
merge 1:1 hosp_id year using $IN_EHRPROG
drop if _merge==2

forval i=2011/2013 {
    replace ehr_prog`i' = 0 if ehr_prog`i'==.
}
egen paid_by_mcr = rowmax(ehr_prog*)

drop _merge
*/





* Expand to include 2006 and 2007 for merge of AHA [later]?

merge 1:1 hosp_id year using $IN_AHA


tab serv _merge

drop if _merge==2
drop _merge

egen id = group(hosp_id)

xtset id year


********************
** New variables
*********************

/* Assume "N"(3) is really 0; 1 is partial; 2 is full*/
replace ehlth = 0 if ehlth==3
gen ehr_part = ehlth==1
gen ehr_full = ehlth==2
gen ehr_any = ehr_full | ehr_part
gen ehr_miss = ehlth==.

* Impute emr from AHA ehlth
tab emr ehlth, miss
replace emr = 0 if ehlth==0 & emr==. & year>=2008
//replace emr = 0 if ehlth==. & emr==. & year>=2008
replace emr = 100 if ehlth==2 & emr==. & year>=2008


// EMR after AHA imputation
tab emr ehlth, miss

sort id year
*Impute emr within panel
replace emr = l.emr if l.emr==f.emr & emr==.

gen takeup = emr==100 | emr>l.emr

xtdescribe if emr!=.
cap log close

tab emr ehlth, miss

*tab year cpoe_frac, miss

tab year, summ(revmedicare)
tab year, summ(revmedicaid)
tab year, summ(revmanage)
tab year, summ(revtradcomm)
tab year, summ(revother)

egen rev_total = rowtotal(rev*)

tab year, summ(rev_total)

summ revmedicaid if year==2011, d

summ revmedicare if year==2011, d

tab rev_total

tab year, summ(netoperr)
tab year, summ(totaloper)

cap log close



foreach val in 0 25 50 75 100 {
    gen emr_`val' = emr_frac==`val'
    *gen cpoe_`val' = cpoe_frac==`val'
}

* Indexes of Quality
foreach metric in mort read core {
    
    if "`metric'"=="core" {
        foreach var in ami8a hf1 pn2 scipvte1 scipinf3 scipvte2 vte5 stk4 pn7 {
            egen mean1_`var'`metric' = mean(`var') //, by(year)
            egen sd1_`var'`metric' = sd(`var') //, by(year)
            gen z_`var'`metric' = (`var' - mean1_`var'`metric')/sd1_`var'`metric'
        }
    }
    else {    
        foreach var in ha hf pn {
            egen mean1_`var'`metric' = mean(`var'_`metric') //, by(year)
            egen sd1_`var'`metric' = sd(`var'_`metric') //, by(year)
            gen z_`var'`metric' = (`var'_`metric' - mean1_`var'`metric')/sd1_`var'`metric'
        }
    }
    egen z_`metric' = rowmean(z_*`metric')
    egen mean2`metric' = mean(z_`metric') //, by(year)
    egen sd2`metric' = sd(z_`metric') //, by(year)
    replace z_`metric' = (z_`metric' - mean2`metric')/sd2`metric'

}

    // Norm quality measures so "good" is positive
replace z_read = -z_read
replace z_mort = -z_mort

summ mean1* mean2* z*
drop mean1* mean2*

******************
** Gen new Variables (pre-130723 in reg files)
*******************

drop ehr*

/*
label def owners 1 "For Profit" 2 "Not For-profit" 3 "Gov, local"
label val owner owners
*/

gen post = year>=2010

* EMR dummies
gen emr_any = emr_frac!=0
gen emr_geq50 = inlist(emr_frac,75,100)
gen emr_leq50 = inlist(emr_frac,25,50)
gen emr_geq75 = emr_frac==100

* EMR ES dummies
forval yr = 2008/2011{
    gen emr_any_`yr' = emr_any*(year==`yr')
    gen emr_geq50_`yr' = emr_geq50*(year==`yr')
    gen emr_leq50_`yr' = emr_leq50*(year==`yr')
}    

gen emr_any_post = emr_any*post
gen emr_geq50_post = emr_geq50*post
gen emr_leq50_post = emr_leq50*post



gen avgwage = paytot/fte
gen cost_per_bed = totaloper/beds_h


cap drop temp
***************************
*    EMR incentive program variables
***************************
/*
    Data dependencies.
        AHA: serv (in HIMSS?); mcripdh, mcdipdh, ipdh
        HIMSS: revmedicaid (old measure);

*/

* CMS hospital type suffix
gen cms_suffix = real(substr(hosp_id,3,4))
gen qualified_no = inrange(cms,1,879) | inrange(cms,1300,1399)
gen childrens = inrange(cms,3300,3399)


        * Medicare
gen temp = serv==10 if serv!=.
egen qual_mcr = max(temp)
drop temp

gen temp = mcripdh / (ipdh) // Charity deflator missing, D.Cutler says NBD
egen paysh_mcr = mean(temp), by(id)
drop temp

local discharge admh



gen temp = (2e6 + max(0,min(`discharge'-1149,23000-1149))*200)*paysh_mcr*qual_mcr if !inlist(.,`discharge',paysh_mcr,qual_mcr)
egen temp2 = mean(temp) if inrange(year,2009,2010), by(id)
egen temp3 = max(temp2), by(id)
gen bene_mcr = temp3*2.5
drop temp temp2 temp3


        *Medicaid
* Our previous volume dummy
gen old_sh10 = revmedicaid >=10 if revmedicaid<.

* Patient volume cutoff (Medicaid inpatient days over total inpatient days, 'cause data)
gen sh_mcd = mcdipdh/ipdh // Should be "encounters" which include ER visits
gen sh10 = sh_mcd>=.1 if sh_mcd!=.

* Qualifier dummy
gen temp = childrens | (qualified_no & sh10) if !inlist(.,childrens,qualified_no,sh10)
egen qual_mcd = max(temp), by(id)
drop temp

* Actual payment
gen temp = mcdipdh / (ipdh ) // CHARITY DEFLATOR MISSING HERE
egen temp2 = max(temp) if inrange(year,2010,2011), by(id)
egen paysh_mcd= max(temp2), by(id)
drop temp temp2

gen adm_g = `discharge'/l.`discharge' - 1 if year<=2010
egen avggrowth = mean(adm_g), by(id)

// Predict future discharges
gen temp = `discharge' if year==2010
replace temp = `discharge' if year==2011 & l.`discharge'==.
bys id: egen pred2010 = max(temp)
gen pred2011 = pred2010*(1+avggrowth)
gen pred2012 = pred2011*(1+avggrowth)
gen pred2013 = pred2012*(1+avggrowth)
drop temp


local discount = 1
forval y=2010/2013 {
    gen pay`y' = (2e6 + max(0,min(pred`y'-1149,23000-1149))*200)*`discount'
    local discount = `discount' - 0.25
}

egen temp = rowtotal(pay2010-pay2013)
egen subtot = rowmean(pay2010-pay2013)
replace subtot = subtot*4
summ temp subtot

gen bene_mcd = paysh_mcd*subtot*qual_mcd


drop temp*


gen lag_leq50 = l.emr_leq50
gen lag_leq50_post = lag_leq50*post

xi i.year

compress



gen bene_tot = bene_mcr+bene_mcd
summ bene*

xtsum bene*

foreach var in noftotdischarge netoperr totalopere ftetotal {
    replace `var' = . if n_`var'==0
}

label def stati 1 "Live" 2 "To be Replaced" 3 "Installing" 4  "Contracted only" 5 "Not yet contracted" 6 "Not automated"  7 "Service not provided" 99 "Not reported" 9999 "Missing"
foreach var of varlist app_* {
    label val `var' stati
}

* Flag for "hosp always exists"
gen iscoreyear = inrange(year, 2008, 2011)
bys hosp_id: egen num_coreyears = total(iscoreyear)
gen byte existsincoreyears = num_coreyears == 4
drop iscoreyear num_coreyears

save $OUT_COMBINED, replace

