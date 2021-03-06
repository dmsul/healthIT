args `subroutine'
cap log close

quiet {
set trace off
set more off
clear all

run src/globals


**************************
**        I/O
**************************

global REG_PREP reg-1403-prep

global PLOT_STEM ../gph/plot-1403

global out ../out/1501

* Paramters
*-----------
/* 4 references:
    1) cpoe (since 2008)
    2) basic (w/ notes) since 2008
    3) Comprehensive since 2008
    4) None
*/

global LHV_z z_core z_read z_mort
global LHV_hospcomp z_scipinf3 z_scipvte2 z_vte5 z_stk4 z_pn7
global LHV_1st our_basic_notes our_comprehensive

* routines
*----------

prog def prep_hosp_data
    /* Get hospitals' EMR usage patterns over time.
       (This used to be its own file, regs-*-prep.do) */

    args control takeuponly

    use $regready_dta, clear
    order hosp_id sysid year

    keep if existsincoreyears == 1

    * Variables for IT adoption status
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
        gen byte always = cpoe_min2008==1
        gen byte never = cpoe_max2008==0
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

    gen byte adopter = always==0 & never==0

    cap drop takeup
    gen takeup = -1*never + always
    label def takers -1 "Never" 0 "Adopters" 1 "Always"
    label values takeup takers

    label var live_cpoe "Live CPOE"
    label var our_basic_notes "BasicN"
    label var our_comprehensive "Comprehensive"

    _prep_healthsystem_vars
    
    * Maybe prune variables, save
    ren syssizemin syssize
    if `takeuponly' == 1 {
        keep hosp_id sysid year takeup size syssize sysid system_change ///
                has_system_change
        keep if year == 2011

        // To merge with patient data
        ren hosp_id provider

        save $DATA_PATH/tmp_takeupflag, replace
    }

end
prog def _prep_healthsystem_vars
        /* To be used on 'regready_dta' data */

        * Impute system if sysid = "" probably wrong
        // Get modal sys and 'how' modal it is
        bys hosp_id: egen modal_sys = mode(sysid), miss
        gen is_modal = sysid == modal_sys
        bys hosp_id: egen count_modal_sys = total(is_modal)
        // Make sure onlyl 4 years before using impute rule
        qui summ year
        assert r(max) == 2011 & r(min) == 2008
        // Impute
        replace sysid = modal_sys if sysid == "" & count_modal_sys == 3 & modal_sys != ""
        // cleanup
        drop modal_sys count_modal_sys is_modal

        * Flag system changes
        bys hosp_id (year): gen system_change = sysid != sysid[_n -1]
        replace system_change = 0 if year == 2008
        bys hosp_id: egen has_system_change = max(system_change)

        * System size
        // Don't lump missings as one system
        replace sysid = hosp_id if sysid == ""
        assert sysid != ""
        // W/in year
        egen systag = tag(sysid year)
        bys sysid year: gen syssizeyear = _N
        egen tmp = cut(syssize), at(0, 1, 2, 5, 10, 20, 50, 100, 200)
        bys sysid: egen syssizemax = max(syssizeyear)
        bys sysid: egen syssizemin = min(syssizeyear)

        egen rep_sysyear = tag(sysid year)
        egen rep_sys = tag(sysid)

end

prog def _load_patient_data
    args Xbins diagnosis

    use $basic_cms_panel, clear

    *Restrict sample
    keep if year >= 2008
    // Drop anyone who doesn't have all outcomes in data
    keep if !inlist(., los, mort30, readmit_30)
    // Use only medicare-age patients
    keep if age_at_adm >= 65

    * Restrict to single diagnosis (if passed; might restrict later)
    if "`diagnosis'" != "" keep if `diagnosis' == 1

    * Make age-sex dummies (if needed)
    if `Xbins' == 1 {
        forval fem=0/1 {
            foreach agecut in 69 74 77 80 82 84 87 90 999  {
                if `agecut' == 69 local agecut_1 = -1
                gen byte agebin`agecut'_fem`fem' = (`agecut_1' < age_at_adm) ///
                                                    & (age_at_adm <= `agecut') ///
                                                    & (female == `fem')
                local agecut_1 = `agecut'
            }
        }
        drop agebin69_fem0
    }

end

prog def _plot_patient_means_by_takeup
    args diagnosis

    _load_patient_data 0 `diagnosis'

    // Merge in hosp's takeup info
    merge m:1 provider using $DATA_PATH/tmp_takeupflag, keep(3) nogen

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

prog def _pat_ESreg_by_takeup

    _load_patient_data 1

    merge m:1 provider using $DATA_PATH/tmp_takeupflag, keep(3) nogen

    * Gen Takeup-ES vars
    foreach status in 0 1 {
        if `status' == -1 local status_name never
        else if `status' == 0 local status_name adopter
        else if `status' == 1 local status_name always
        forval y = 2009/2012 {
            gen byte `status_name'_`y' = (year==`y') * (takeup == `status')
        }
    }

    * Regs
    local patXs agebin* race_*
    local replace replace
    foreach diagnosis in heart_failure ami hipfrac pneumonia {
        foreach lhv in los mort30 readmit_30 {
            qui summ `lhv' if `diagnosis' == 1 & year==2008 & takeup == -1
            local never_mean = r(mean)
            qui summ `lhv' if `diagnosis' == 1 & year==2008 & takeup == 0
            local adopt_mean = r(mean)
            qui summ `lhv' if `diagnosis' == 1 & year==2008 & takeup == 1
            local always_mean = r(mean)
            areg `lhv' adopter_* always_* `patXs' i.year if `diagnosis' == 1, ///
                 a(provider) cluster(provider)
            outreg2 using ../out/1410/cms_${control_var}.txt, `replace' ///
                addtext(Diag, "`diagnosis'", FE, "provider", Cluster, "provider", ///
                        Never Mean, `never_mean', Adopt Mean, `adopt_mean', Always Mean, `always_mean')
            local replace
        }
    }
end

prog def main_pat_plot_means_takeup
    foreach emr_type in 1 2 3 0 {
        foreach diag in heart_failure ami hipfrac pneumonia {
            prep_hosp_data `emr_type' 1
            _plot_patient_means_by_takeup `diag'
        }
    }
end

prog def main_patient_ESregs_simple
    /* ES regs by diagnosis assuming constant effects over time for all
     * hospitals */

    _load_patient_data 1

    * Regs
    local patXs agebin* race_*
    local replace replace
    foreach diagnosis in heart_failure ami hipfrac pneumonia {
        foreach lhv in los mort30 readmit_30 {
            qui summ `lhv' if `diagnosis' == 1 & year==2008
            local pop_mean = r(mean)
            areg `lhv' i.year `patXs' if `diagnosis' == 1, ///
                 a(provider) cluster(provider)
            outreg2 using ../out/1410/cms_simple.txt, `replace' ///
                addtext(Diag, "`diagnosis'", FE, "provider", Cluster, "provider", 2008 Mean, `pop_mean')
            local replace
        }
    }
end

prog def main_patient_ESregs_by_takeup
    /* ES regs with separate event studies for firms by hosp EMR use categorys
     * 'never', 'always', and 'adopters'. Several definitions of EMR are used,
     * indexed by "emr_type" */

    foreach emr_type in 1 2 3 {
        prep_hosp_data `emr_type' 1
        _pat_ESreg_by_takeup
    }
end

prog def main_summ_system
    prep_hosp_data 2 0 

    egen rep_hosp = tag(hosp_id)

    keep if syssizemin >=5

    * System size
    hist syssizemax if rep_sys == 1, ti("System size (# hosps {&ge}5)") 
    graph export $out/sys_histsize.png, width(1500) replace

    * System changers
    summ has_system_change if rep_hosp == 1
    tab year system_change

    * Adoption by system size
    foreach var in never always adopter {
        bys sysid: egen mean_`var' = mean(`var')
        twoway (scatter mean_`var' syssizemin) if rep_sys == 1  , name(`var')
        graph export $out/sys_size_`var'.png, width(1500) replace
    }
    * Misc hosp X's dispersion w/in system
    foreach var in frac_mdemp_2010 {
        bys sysid: egen mean_`var' = mean(`var')
        bys sysid: egen hi_`var' = pctile(`var'), p(80)
        bys sysid: egen lo_`var' = pctile(`var'), p(20)
        twoway (line lo_`var' lo_`var') (scatter hi_`var' lo_`var') if rep_sys ==1, ///
               yti("Sys's high value (80)") xti("Sys's low value (20)") ///
               ti("W/in system spread of `var'")
        graph export $out/sys_disp_scatter_`var'.png, replace
        gen d_`var' = hi_`var' - lo_`var'
        hist d_`var' if rep_sys == 1, xti("Hi/low difference") ti("System `var'")
        graph export $out/sys_disp_hist_`var'.png, replace
    }
end

prog def main_patient_sysfx
    args focus

    * Get hosp-sys xwalk w/ size
    prep_hosp_data 2 0
    keep if year == 2010
    ren hosp_id provider
    ren syssizemin syssize
    keep provider sysid syssize
    tempfile hospsys
    compress
    save `hospsys'

    * Prep patient data
    _load_patient_data 1

    merge m:1 provider using `hospsys', keep(3) nogen

    keep if syssize >=5

    local patXs agebin* race_*
    local replace replace
    foreach diagnosis in heart_failure ami hipfrac pneumonia {
        foreach lhv in los mort30 readmit_30 {
            // Get baseline mean of LHV
            qui summ `lhv' if `diagnosis' == 1 & year==2008
            local pop_mean = r(mean)

            * System reg
            areg `lhv' i.year `patXs' if `diagnosis' == 1, ///
                 a(sysid) cluster(provider)
            outreg2 using $out/sysfx.txt, `replace' ///
                addtext(Diag, "`diagnosis'", FE, "system", ///
                        Cluster, "provider", 2008 Mean, `pop_mean')
            // Get SSR_r
            local ssr_r = e(rss)

            * Hosp reg
            areg `lhv' i.year `patXs' if `diagnosis' == 1, ///
                 a(provider) cluster(provider)

            // Do LM test
            local ssr_u = e(rss)
            foreach fxvar in sysid provider {
                egen tag_`fxvar' = tag(`fxvar') if e(sample)
                qui summ tag_`fxvar'
                local num_`fxvar' = r(sum)
            }
            local q = `num_provider' - `num_sysid'
            local dfr = e(N) - e(df_m) - e(df_a) -1
            local F = ((`ssr_r' - `ssr_u') / `q') / (`ssr_u' / `dfr')
            local pF = 1 - F(`q', `dfr', `F')
            di "F-stat is " `F'
            di "p is " `pF'

            outreg2 using $out/sysfx.txt, ///
                addtext(Diag, "`diagnosis'", FE, "provider", ///
                        Cluster, "provider", 2008 Mean, `pop_mean', ///
                        FX_F, `F', FX_p, `pF')
            local replace

            * Summ w/in system patterns
            preserve
            predict hosp_fx, d
            keep if tag_provider == 1
            egen rep_sys = tag(sysid)
            // Density of hosp_fx
            bys sysid: egen syss_m = mean(hosp_fx)
            bys sysid: gen N = _N
            gen hosp_fx_win = hosp_fx - syss_m
            summ hosp_fx_win, d
            twoway (kdensity hosp_fx) (kdensity hosp_fx_win), ///
                   legend(lab(1 "Hosp FE") lab(2 "Hosp FE (demeaned)"))
            graph export $out/sysfx_kdens_`diagnosis'_`lhv'.png, replace
            // StdDev w/in system
            qui summ hosp_fx
            local pop_sd = r(sd)
            bys sysid: egen syssd = sd(hosp_fx)
            hist syssd if rep_sys == 1, ///
                xti("W/in system std dev") xline(`pop_sd')
            graph export $out/sysfx_hist_`diagnosis'_`lhv'.png, replace
            // System rank range
            xtile fx_rank = hosp_fx, n(100)
            bys sysid: egen rank_80 = pctile(fx_rank), p(80)
            bys sysid: egen rank_20 = pctile(fx_rank), p(20)
            twoway (line rank_20 rank_20) (scatter rank_80 rank_20) ///
                if rep_sys == 1, yti("Highest rank (80)") xti("Lowest rank (20)") ///
                legend(off)
            graph export $out/sysfx_scatter_`diagnosis'_`lhv'.png, replace
            restore

            drop tag_*
        }
    }
end

prog def main_hosp_sysfx_1st

    * Get hosp-sys xwalk w/ size
    prep_hosp_data 2 0
    ren hosp_id provider

    keep if syssizemin >=5

    local replace replace
    foreach lhv in live_cpoe our_basic_notes our_comprehensive {
        // Get baseline mean of LHV
        qui summ `lhv' if year==2008
        local pop_mean = r(mean)

        * System reg
        areg `lhv' i.year, a(sysid) cluster(provider)
        outreg2 using $out/sysfx_1st.txt, `replace' ///
            addtext(FE, "system", ///
                    Cluster, "provider", 2008 Mean, `pop_mean')
        // Get SSR_r
        local ssr_r = e(rss)

        * Hosp reg
        areg `lhv' i.year , a(provider) cluster(provider)

        // Do LM test
        local ssr_u = e(rss)
        foreach fxvar in sysid provider {
            egen tag_`fxvar' = tag(`fxvar') if e(sample)
            qui summ tag_`fxvar'
            local num_`fxvar' = r(sum)
        }
        local q = `num_provider' - `num_sysid'
        local dfr = e(N) - e(df_m) - e(df_a) -1
        local F = ((`ssr_r' - `ssr_u') / `q') / (`ssr_u' / `dfr')
        local pF = 1 - F(`q', `dfr', `F')
        di "F-stat is " `F'
        di "p is " `pF'

        outreg2 using $out/sysfx_1st.txt, ///
            addtext(FE, "provider", ///
                    Cluster, "provider", 2008 Mean, `pop_mean', ///
                    FX_F, `F', FX_p, `pF')
        local replace

        * Summ w/in system patterns
        preserve
        predict hosp_fx, d
        keep if tag_provider == 1
        cap drop rep_sys
        egen rep_sys = tag(sysid)
        // Density of hosp_fx
        bys sysid: egen syss_m = mean(hosp_fx)
        bys sysid: gen N = _N
        gen hosp_fx_win = hosp_fx - syss_m
        summ hosp_fx_win, d
        twoway (kdensity hosp_fx) (kdensity hosp_fx_win), ///
               legend(lab(1 "Hosp FE") lab(2 "Hosp FE (demeaned)"))
        graph export $out/sysfx1st_kdens_`lhv'.png, replace
        // StdDev w/in system
        qui summ hosp_fx
        local pop_sd = r(sd)
        bys sysid: egen syssd = sd(hosp_fx)
        hist syssd if rep_sys == 1, ///
            xti("W/in system std dev") xline(`pop_sd')
        graph export $out/sysfx1st_hist_`lhv'.png, replace
        // System rank range
        xtile fx_rank = hosp_fx, n(100)
        bys sysid: egen rank_80 = pctile(fx_rank), p(80)
        bys sysid: egen rank_20 = pctile(fx_rank), p(20)
        twoway (line rank_20 rank_20) (scatter rank_80 rank_20) ///
            if rep_sys == 1, yti("Highest rank (80)") xti("Lowest rank (20)") ///
            legend(off)
        graph export $out/sysfx1st_scatter_`lhv'.png, replace
        restore

        drop tag_*
    }
end

prog def main_patient_misc
    * Get hosp-sys xwalk w/ size
    prep_hosp_data 2 0
    keep if year == 2010
    ren hosp_id provider
    ren syssizemin syssize
    keep provider sysid syssize frac_mdemp_2010
    tempfile hospsys
    compress
    save `hospsys'

    * Prep patient data
    _load_patient_data 1

    merge m:1 provider using `hospsys', keep(3) nogen

    assert sysid != ""
    gen byte in_sys = sysid != provider
    forval yr=2009/2012 {
        gen byte in_sys_y`yr' = in_sys * (year == `yr')
        gen frac_mdemp_y`yr' = frac_mdemp_2010 * (year == `yr')
    }

    local patXs agebin* race_*
    local replace replace
    foreach diagnosis in heart_failure ami hipfrac pneumonia {
        foreach lhv in los mort30 readmit_30 {
            // Get baseline mean of LHV
            di "Diag: `diagnosis'"
            qui summ `lhv' if `diagnosis' == 1 & year==2008
            local pop_mean = r(mean)

            * System reg
            areg `lhv' in_sys_y* i.year `patXs' if `diagnosis' == 1, ///
                 a(provider) cluster(provider)
            outreg2 using $out/misc_2nd.txt, `replace' ///
                addtext(Diag, "`diagnosis'", FE, "provider", Cluster, "provider", 2008 Mean, `pop_mean')
            local replace

            areg `lhv' frac_mdemp_y* i.year `patXs' if `diagnosis' == 1, ///
                 a(provider) cluster(provider)
            outreg2 using $out/misc_2nd.txt, 
                addtext(Diag, "`diagnosis'", FE, "provider", Cluster, "provider", 2008 Mean, `pop_mean')

            areg `lhv' frac_mdemp_y* in_sys_y* i.year `patXs' if `diagnosis' == 1, ///
                 a(provider) cluster(provider)
            outreg2 using $out/misc_2nd.txt,  ///
                addtext(Diag, "`diagnosis'", FE, "provider", Cluster, "provider", 2008 Mean, `pop_mean')
        }
    }
end

prog def main_hosp_misc

    prep_hosp_data 2 0
    ren hosp_id provider

    assert sysid != ""
    gen byte in_sys = sysid != provider
    forval yr=2009/2011 {
        gen byte in_sys_y`yr' = in_sys * (year == `yr')
        gen frac_mdemp_y`yr' = frac_mdemp_2010 * (year == `yr')
        gen syssize_y`yr' = syssizemin * (year == `yr')
    }
    local replace replace

    foreach lhv in $LHV_1st $LHV_hospcomp $LHV_z {
        // Get baseline mean of LHV
        qui summ `lhv' if year==2008
        local pop_mean = r(mean)

        areg `lhv' in_sys_y* i.year , a(provider) cluster(provider)
        outreg2 using $out/misc_hosp.txt, `replace' ///
            addtext(FE, "provider", Cluster, "provider", 2008 Mean, `pop_mean')
        local replace

        areg `lhv' frac_mdemp_y* i.year , a(provider) cluster(provider)
        outreg2 using $out/misc_hosp.txt, ///
            addtext(FE, "provider", Cluster, "provider", 2008 Mean, `pop_mean')

        areg `lhv' syssize_y* i.year , a(provider) cluster(provider)
        outreg2 using $out/misc_hosp.txt, ///
            addtext(FE, "provider", Cluster, "provider", 2008 Mean, `pop_mean')
    }
end

} // End quiet

`subroutine'
