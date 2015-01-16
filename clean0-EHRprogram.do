quiet {
set more off
set trace off
clear all

run src/globals

prog def _clean_hosp_id
    tempvar orig_length hosp_year_obs
    gen `orig_length' = length(hosp_id)
    // Assert hosp_id-year is unique before we start
    bys hosp_id year: gen `hosp_year_obs' = _N
    cap assert `hosp_year_obs' == 1 if `orig_length' > 0
    if _rc != 0 {
        di as err "hosp_id-year not unique to begin with!"
        error 999
    }
    // ID should be 6 digits
    replace hosp_id = "0" + hosp_id if `orig_length' == 5
    replace hosp_id = substr(hosp_id,1,6)
    assert length(hosp_id) == 6 | `orig_length' == 0
    // Check again for uniqueness
    bys hosp_id year: replace `hosp_year_obs' = _N
    cap assert `hosp_year_obs' == 1 if length(hosp_id) > 0
    if _rc != 0 {
        di as err "hosp_id-year not unique after cleaning!"
        error 999
    }
end

prog def clean_cms_ehr_payments
    clear
    insheet using $DATA_PATH/source/cms_ehrprog/EH_ProvidersPaidByEHR_09_2014_FINAL.csv
    drop if providernpi == "HOSPITALS" // Stupid second line

    ren providerccn     hosp_id
    ren programyear     year
    ren calcpaymentamt  cms_payment 
    foreach var of varlist provider* {
        local newname = subinstr("`var'", "provider", "", .)
        ren `var' `newname'
    }

    * Convert string dollars to numeric
    gen byte is_neg = regexm(cms_payment, "[\(\)]")
    destring cms_payment, ignore(",$()") replace
    replace cms_payment = -1 * cms_payment if is_neg == 1
    drop is_neg

    * Handle non-unique hops_id-year sets
    /* Phone number (w/ ext) consistently different. One differs in address,
       another differns in npi. No idea. [1/15/15, DMS]. */
    // Check that hosp_id isn't picking up two different institutions
    foreach var in orgname state city {
        di "Assert `var'"
        bys hosp_id year: assert (`var' == `var'[_n - 1]) | (_n == 1)
    }
    // flag the weirdos anyway
    bys hosp_id year: gen tmp_n = _N
    gen byte had_dup_in_ehr_pay = (tmp_n > 1)
    label var had_dup_in_ehr_pay "See clean0-EHRprogram.do"
    drop tmp_n
    // Sum within duplicates
    collapse (sum) cms_payment, by(hosp_id year)

    * Clean hosp_id (now that we've handled non-uniques)
    _clean_hosp_id

    *Write
    compress
    save $cms_ehr_payments_dta, replace
end

/*
Notes for CMS EHR Meangingful Use data. The following two documents give
(conflicting) definitions of the CM variables:
http://www.cms.gov/Regulations-and-Guidance/Legislation/EHRIncentivePrograms/Downloads/Hospital_Attestation_Stage1Worksheet_2014Edition.pdf
https://www.cms.gov/Regulations-and-Guidance/Legislation/EHRIncentivePrograms/downloads/EP-MU-TOC.pdf)

Issues:
    -- First file matches data types through 11, but only goes to 11.
    -- Second file goes to 14, but doesn't match dtypes starting in CM9

Definitions:
CM1 - medication orders done through CPOE = CPOE patients w/ meds
        (or raw orders) over total
    - Cutoff 30% (Exempt: EP's who write fewer than 100 scripts)
CM2 - Drug-drug and drug-allergy interaction checks = Yes/No
CM3 - Up-to-date problem list of current diagnoses
        =  (# patients w/ non-empty problem list) / unique patients
    - Cutoff 80%
CM4 - Make and transmit eRx's if allowed = (eRx's) / (Total eligible)
    - Cutoff 40% (exlusion for <100 scripts or no ePharmacy w/in 10 miles
    - NOTE: Worksheet does not list this.
CM5 - Active medication list = (Non-null med lists) / (Unique patients)
    - Cutoff 80%
    - NOTE: Worksheet lists this as CM4
CM6 - Active medication allergy list = (Non-null allergy list) / (Unique p)
    - Cutoff 80%
    - NOTE: Worksheet lists this as CM5
CM7 - Record various demographics = (# p's w/ data) / (Unique p)
    - Cutoff 50%
    - NOTE: Worksheet lists this as CM6
CM8 - Record and chart vital signs
    - Cutoff 50% of unique patients and 100% of p's under age 2
    - Exclude: no under age 2 p's get it easier (or "EP believes ht,
        wt, and BP 'have no relevance to their scope of practice')
    - NOTE: Worksheet lists this as CM7
CM9 - Record smoking status, age >= 13
    - Cutoff 50% (exclusion, no patients >=13, enter '0' in exclusion box)
    - NOTE: Worksheet lists this as CM8
CM10- Report ambulatory clinical quality measures to CMS (Yes/No)
    - Note: "No longer core objective but still required"
    - NOTE: Worksheet skips this
CM11- Implement one (additional) clinical decision support rule (Yes/No)
    - NOTE: Worksheet lists as CM9
CM12- Provide patients w/ e-copy of their health info upon request
        = (# who get it w/in 3 business days) / (# of requestors)
    - Cutoff 50% (exlusion: No requests)
    - NOTE: Worksheet lists as CM10
CM13- Provide clinical summaries for patients for each office visit
        = (# p getting w/in 3 bus days) / (# office visits)
    - Cutoff 50% (exclusion, no office visits)
    - NOTE: Worksheet skips this
CM14- Protect e-health info (do data security review) (Yes/No)
    - NOTE: Worksheet list as CM11

Other notes: In 2014, the "request records" and "discharge instructions"
    requirements were combined into a "e access and transmit" requirement.

XXX I think these data follow the Worksheet through CM9. Not sure
    after that. [1/15/15, DMS]
*/
prog def clean_cms_MU_measures
    clear
    import excel using "$DATA_PATH/source/cms_ehrprog/20141024 EH PUF - Stage 1-Final.xlsx", case(lower) firstrow

    * These two variables are switched in the raw data
    local ehrcert_lab: var l ehrcertificationnumber
    local attest_date_lab: var l attestationsuccessdate
    ren ehrcertificationnumber temp
    ren attestationsuccessdate ehrcertificationnumber
    ren temp attestationsuccessdate 
    label var attestationsuccessdate "`attest_date_lab'"
    label var ehrcertificationnumber "`ehrcert_lab'"

    * Give meaningful names
    ren attestationsuccessdate attest_date
    ren cm1percentage   CMS_cpoe_orders
    ren cm2             CMS_drug_interact_check
    ren cm3percentage   CMS_problem_list
    ren cm4percentage   CMS_med_list
    ren cm5percentage   CMS_allergy_list
    ren cm6percentage   CMS_rec_demogs
    ren cm7percentage   CMS_rec_vitals
    ren cm8percentage   CMS_rec_smoking
    ren cm9             CMS_one_cds_rule
    // Clear old crappy labels
    foreach var of varlist CMS_* {
        label var `var' ""
    }

    * Fix data types
    // Binary vars are string Y/N, make numeric
    foreach binary_var in CMS_drug_interact_check CMS_one_cds_rule {
        gen byte temp = 1 if `binary_var' == "Y"
        replace temp = 0 if `binary_var' == "N"
        assert temp != .
        drop `binary_var'
        ren temp `binary_var'
    }
    // Make sure string date was imported as int date
    assert "`: type attest_date'" == "int"
    // Recast doubles (just fractions) to float
    ds CMS_*, has(type double)
    recast float `r(varlist)', force
    // Label 
    label var paymentyear "Num yrs in program"

    * Compatibility with other files
    ren ccn hosp_id
    ren programyear year

    _clean_hosp_id  // Requires `year` variable

    * Prune
    /* hosp_id is blank for a bunch of guys (children's hosps maybe), keep npi
     * for that? */
    keep hosp_id npi year attest_date CMS*
    order hosp_id npi year attest_date CMS*

    * Write
    compress
    save $cms_MU_measures_dta, replace
end
} // End subroutine quiet

clean_cms_MU_measures
clean_cms_ehr_payments
