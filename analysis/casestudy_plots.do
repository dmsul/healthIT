args subroutine
/*
    Focus on systems that had large changes in within-system participation
    rates in the EHR incentives program.
*/
set more off

run src/globals
run main // Need `prep_hosp_data`

/*
sysid's
49 - 0180, 0198
50 - 0063
60 - 1775
114 - 0080
*/


prog def plot_hosplvl
    foreach emr_type in  2  {
        prep_hosp_data `emr_type' 1
        foreach diag in heart_failure ami hipfrac pneumonia {
            _plot_patient_means_by_takeup2 `diag'
        }
    }
end

prog def _plot_patient_means_by_takeup2
    /* Plot raw patient means by whatever takeup variables are in data */
    args diagnosis

    _load_patient_data 0 `diagnosis'

    // Merge in hosp's takeup info
    merge m:1 provider using $DATA_PATH/tmp_takeupflag, keep(3) nogen

    keep if inlist(sysid, "0180", "0198", "0063", "1775", "0080")

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
                legend( lab(1 "Adopters") lab(2 "Never") lab(3 "Always") c(3)) ///
                caption("Patient Sample: Always=`n_always', Adopt=`n_adopt', Never=`n_never'")
        graph export $OUT_PATH/${control_var}_`diagnosis'_`outcome'.png, replace width(1000)
    }
    /*
    graph combine live_cpoe our_basic_notes our_comprehensive z_core z_read z_mort, ///
        c(3) title("Control: $control_var") xsize(7) ///
        note("Hospital size: `sizelabel'. Group Obs: Never=`n_never';" ///
                + "Adopters=`n_adopt'; Always=`n_always'")
    graph export $PLOT_STEM-$control_var-`sizelabel'.png, replace width(2000)
    */
end

`subroutine'
