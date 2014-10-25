qui {
//set trace on
set more off
clear all

local starttime = c(current_time)

run src/globals

/*
    diagnosis from inpatient/outpatient files
    merge on 'provider' in CMS and 'hosp_id' in our data
    fac_type = 1 for hospitals
    use DRG for diagnosis

    Outcomes: length of stay, readmission, mortality
*/

* I/O
*-----
global readmit_flag $readmit_flag

global tmp_inpatient $DATA_PATH/tmp_inpatient
global tmp_bsfab_tomerge $DATA_PATH/tmp_bsfab_tomerge
global xwalk_clm_beneid $xwalk_clm_beneid

global OUT_PANEL $basic_cms_panel

* Paramters
*----------
global year0 2006
global yearT 2012


* Subs
*------

prog def flag_readmit
    args cutoff
    if "`cutoff'" == "" local cutoff 30

    clear
    save $DATA_PATH/tmp_readmit, emptyok replace

    foreach year of numlist $year0/$yearT {
        use bene_id clm_id admsn_dt dschrgdt using $CMS_SRC/ip/`year'/ipc`year'
        append using $DATA_PATH/tmp_readmit
        save $DATA_PATH/tmp_readmit, replace
    }
    * Days between discharge and readmission
    bys bene_id (admsn_dt): gen int days_out = dschrgdt[_n+1] - admsn_dt
    gen byte readmit_`cutoff' = days_out <= `cutoff'

    keep clm_id readmit_`cutoff'
    keep if readmit_`cutoff' == 1

    compress
    save $readmit_flag, replace
    rm $DATA_PATH/tmp_readmit.dta
end

prog def flag_dupbeneid
    /* There are erroneously duplicate bene_id's. Gather them up, drop them. */
    save $DATA_PATH/tmp_badbeneid, replace emptyok
    foreach year of numlist $year0/2008 {
        use bene_id benedpsq using $CMS_SRC/bsf/`year'/bsfab`year', clear
        qui count
        local oldN = r(N)
        drop if benedpsq == 0
        qui count
        local newN = r(N)
        di "Year `year': `newN' duplicates in `oldN'"
        keep bene_id
        append using $DATA_PATH/tmp_badbeneid
        save $DATA_PATH/tmp_badbeneid, replace
    }
    bys bene_id: keep if _n==1
    save $DATA_PATH/flag_dupbeneid, replace
end

prog def _inpatient_extract_year
    args year

    local keep_ip_vars bene_id provider drg_cd fac_type admsn_dt dschrgdt clm_id
    use `keep_ip_vars' using $CMS_SRC/ip/`year'/ipc`year'

    destring fac_type drg_cd, replace
    * Keep only hospitals
    keep if fac_type == 1
    drop fac_type
    * Flag diagnoses
    /* w/ mcc, w/ cc, w/o */
    if inlist(`year', 2006, 2007) {         
        local heart_failure_code 127
        local ami_code 121, 122
        local ami_died_code 123
        local hipfrac_code 236
        local pneumonia_code 89, 90, 91 // >17{w/cc, w/o}, <=17
    }
    else {
        local heart_failure_code 291, 292, 293
        local ami_code 280, 281, 282
        local ami_died_code 283, 284, 285
        local hipfrac_code 535, 536
        local pneumonia_code 193, 194, 195
    }
    foreach diagnosis in heart_failure ami ami_died hipfrac pneumonia {
        gen byte `diagnosis' = inlist(drg_cd, ``diagnosis'_code')
    }

    keep if inlist(1, heart_failure, ami, ami_died, hipfrac, pneumonia)
    gen int year = year(admsn_dt)
end

prog def main
    * Create claims panel
    clear
    save $tmp_inpatient, emptyok replace
    foreach year of numlist $year0/$yearT {
        di "Inpatient year `year'"
        qui _inpatient_extract_year `year'
        tab year
        append using $tmp_inpatient
        save $tmp_inpatient, replace
    }
    * Merge in readmit flag
    merge 1:1 clm_id using $readmit_flag, keep(1 3) nogen
    replace read = 0 if read == .
    drop clm_id
    * Merge in patient demog data 
    local demog_vars bene_dob sex race death_dt
    gen byte _runmerge = 0
    foreach year of numlist $yearT(-1)$year0 {
        /*
            Should be m:1 but bsfab is non-unique. Since we've already dropped
            bene_id's with duplicates, this shouldn't be a problem (except maybe
            computationally slow?)
            Also, only year<=2008 has duplicates, so we only drop once we get
            there
        */
        di "Merging in A/B `year'"
        if `year' > 2008 {
            merge m:1 bene_id using $CMS_SRC/bsf/`year'/bsfab`year', ///
                  keep(1 3 4 5) keepusing(`demog_vars') update
        }
        else if `year' == 2008 {
            * Flag and drop bene_id's with duplicates
            merge m:1 bene_id using $DATA_PATH/flag_dupbeneid, keep(1 3)
            drop if _merge==3 & _runmerge==1
            drop _merge

            merge m:m bene_id using $CMS_SRC/bsf/`year'/bsfab`year', ///
                  keep(1 3 4 5) keepusing(`demog_vars') update
        }
        else {
            merge m:m bene_id using $CMS_SRC/bsf/`year'/bsfab`year', ///
                  keep(1 3 4 5) keepusing(`demog_vars') update
        }
        replace _runmerge = max(_merge, _runmerge)
        drop _merge
    }

    * Make sure not too many missed demog merges
    tab _runmerge
    local totalN = `=_N'
    qui count if _runmerge==1
    local missedN = r(N)
    assert `missedN'/`totalN' < 0.001
    drop _runmerge

    * Gen new vars
    // Dates
    gen los = dschrgdt - admsn_dt
    gen days_to_death = death_dt - admsn_dt
    gen mort30 = days_to_death <= 30
    gen age_at_adm = int(admsn_dt - bene_dob)/365.25
    drop if days_to_death < 0
    drop if age_at_adm < 0
    drop dschrgdt death_dt days_to_death
    // Sex
    drop if sex == ""
    gen byte female = sex == "2"
    drop sex
    // Race
    gen byte race_black = race == "2"
    gen byte race_hisp = race == "5"
    gen byte race_oth = !inlist(race, "1", "2", "5")
    drop race

    * Save!
    keep if inrange(year, $year0, $yearT)
    // Drop last 3 months to avoid truncation problems
    drop if admsn_dt > mdy(10, 1, $yearT)
    compress
    save $OUT_PANEL, replace
end

} // End quiet


* Main
*-----
//flag_readmit
//flag_dupbeneid
main

//rm $tmp_inpatient.dta

di "!!!!FINSHED!!!!
di "Started at `starttime'"
di "Finished at " c(current_time)

