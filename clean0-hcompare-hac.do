set trace off
set more off
clear all

run src/globals

prog def main
    clear
    tempfile append_base
    save `append_base', emptyok
    foreach vintage in "20120401" "20130401" {
        load_hac_scores_year `vintage'
        append using `append_base'
        save `append_base', replace
    }
    save $DATA_PATH/hospitals_hac, replace
end

prog def load_hac_scores_year
    args vintage
    insheet using $HCOMPARE_SRC/vwHQI_HOSP_HAC_`vintage'.csv, names clear
    * Rename/clean `hosp_id`
    ren prvdr_id hosp_id
    replace hosp_id = subinstr(hosp_id, "'", "", .)

    * Reshape, one var for each HAC measure
    replace msr_cd = subinstr(msr_cd, "HAC_", "", .)
    destring msr_cd, replace

    * Destring score
    gen tmp = real(scr)
    ren tmp hac
    drop scr

    reshape wide hac, i(hosp_id) j(msr_cd)

    * Standardize
    foreach var of varlist hac* {
        egen temp_mean = mean(`var')
        egen temp_sd = sd(`var')
        gen z_`var' = (`var' - temp_mean) / temp_sd
        drop temp_mean temp_sd
    }

    * Label
    forval i=1/8 {
        if `i' == 1 local this_label "Foreign object retained after surgery"
        else if `i' == 2 local this_label "Air embolism"
        else if `i' == 3 local this_label "Blood compatibility"
        else if `i' == 4 local this_label "Pressure ulcer stages 3 & 4"
        else if `i' == 5 local this_label "Falls and trauma"
        else if `i' == 6 local this_label "Vascular catheter-associated infections"
        else if `i' == 7 local this_label "Catheter-associated urinary tract infection"
        else if `i' == 8 local this_label "Manifestations of poor glycemic control"
        label variable hac`i' "`this_label'"
        label variable z_hac`i' "`this_label' (z score)"
    }

    * Recase doubles as floats
    ds _all, has(type double)
    foreach var in `r(varlist)' {
        recast float `var', force
    }

    * Set year
    /*  20120401 covers *unknown*
        20130401 covers 2009Q3 - 2011Q2 */
    local year = real(substr("`vintage'", 1, 4)) - 2
    gen year = `year'
end
 

main
