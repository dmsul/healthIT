/*
    Regressions using data from HospCompare and AHA.

    ***Assume for EHR that 0 = no; 1 = partial, 2 = full, N = no
    
    
*/
set more off
clear all

run src/globals


**************************
**        I/O
**************************

global REG_PREP reg-1403-prep

global PLOT_STEM ../gph/plot-1403


* Paramters
*-----------
/* 4 references:
    1) cpoe (since 2008)
    2) basic (w/ notes) since 2008
    3) Comprehensive since 2008
    4) None
*/


* routines
*----------

prog def gen_takeup_flags
    args control

    use $regready_dta, clear

    * somthing
    foreach year in 2008 {
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
    if `control'==1 {
        gen always = cpoe_min2008==1
        gen never = cpoe_max2008==0
        global control_var "cpoe"
        drop if year<2008
    }
    else if `control'==2 {
        gen always = basicn_min2008==1
        gen never = basicn_max2008==0
        global control_var "basicn"
        drop if year<2008
    }
    else if `control'==3 {
        gen always = compreh_min2008==1
        gen never = compreh_max2008==0
        global control_var "compreh"
        drop if year<2008
    }
    else if `control'==0 {
        gen always = 0
        gen never = 0
        global control_var "none"
        drop if year<2008
    }

    gen adopter = always==0 & never==0

    cap drop takeup
    gen takeup = -1*never + always
    label def takers -1 "Never" 0 "Adopters" 1 "Always"
    label values takeup takers

    label var live_cpoe "Live CPOE"
    label var our_basic_notes "BasicN"
    label var our_comprehensive "Comprehensive"

    * Prune variables, save
    keep hosp_id takeup size
    ren hosp_id provider
    duplicates drop

    save $DATA_PATH/tmp_takeupflag, replace
end

prog def main_plot
    args diagnosis ami_flag

    use $basic_cms_panel, clear

    keep if year >= 2008 & `diagnosis' == 1
    // Drop anyone who doesn't have all outcomes in data
    keep if !inlist(., los, mort30, readmit_30)
    // Merge in hosp's takeup info
    merge m:1 provider using $DATA_PATH/tmp_takeupflag
    keep if _merge==3
    drop _merge

    collapse (count) count=los (mean) los mort30 readmit_30, by(takeup year)

    qui summ count if takeup==-1 & year==2010
    local n_never = r(mean)
    qui summ count if takeup==0 & year==2010
    local n_adopt = r(mean)
    qui summ count if takeup==1 & year==2010
    local n_always = r(mean)

    foreach outcome in los mort30 readmit_30 {        

        twoway  (connected `outcome' year if takeup==0) ///
                (connected `outcome' year if takeup==-1) ///
                (connected `outcome' year if takeup==1), ///
                xlab(2008/2012) ti("`diagnosis', `outcome', $control_var") ///
                legend( lab(1 "Adopters") lab(2 "Never") lab(3 "Always") c(3))
        graph export ../out/1410/${control_var}_`outcome'.png, replace width(1000)
    }
    /*
    graph combine live_cpoe our_basic_notes our_comprehensive z_core z_read z_mort, ///
        c(3) title("Control: $control_var") xsize(7) ///
        note("Hospital size: `sizelabel'. Group Obs: Never=`n_never';" ///
                + "Adopters=`n_adopt'; Always=`n_always'")
    graph export $PLOT_STEM-$control_var-`sizelabel'.png, replace width(2000)
    */
end

// set trace on
foreach emr_type in 1 2 3 0 {
    foreach diag in heart_failure ami hipfrac pneumonia {
        gen_takeup_flags `emr_type'
        main_plot `diag'
    }
}


