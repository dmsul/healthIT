set trace off
set more off
clear all

run src/globals

global out $OUT_PATH

prog def payments_only

    use $cms_ehr_payments_dta, clear

    bys hosp_id (year): gen first_year = _n == 1

    twoway ///
        (kdensity cms_payment if year == 2011 & first_year == 1) ///
        (kdensity cms_payment if year == 2012 & first_year == 1) ///
        (kdensity cms_payment if year == 2013 & first_year == 1) ///
        , legend(lab(1 "2011") lab(2 "2012") lab(3 "2013") row(1)) ///
        title("Payments for entry year")
    graph export $out/cmsprog_payment_density.png, width(1500) replace

    collapse (mean) mean=cms_payment ///
             (p50) p50=cms_payment ///
             (p25) p25=cms_payment ///
             (p75) p75=cms_payment ///
             (sum) sum=cms_payment ///
             (count) count=cms_payment ///
             , by(year)

    twoway connected p25 p50 p75 year, xti("Incentive Pay ($)")
    graph export $out/cmsprog_payment_quantiles_ts.png, width(1500) replace

    twoway (connected count year) (connected mean year, yaxis(2))
    graph export $out/cmsprog_payment_summ_ts.png, width(1500) replace
end

prog def payments_by_syssize
    clear
    use $regready_dta
    gen byte in_sys = sysid != ""
    replace sysid = hosp_id if sysid == ""
    bys sysid year: gen syssize = _N

    keep hosp_id year sysid in_sys syssize
    keep if year == 2011

    ren syssize syssize2011

    drop year
    expand 4
    bys hosp_id: gen year = _n + 2010
    tempfile hosp_sys_info
    save `hosp_sys_info'



    // Merge in system dummies

    use $cms_ehr_payments_dta, clear

    merge 1:1 hosp_id year using `hosp_sys_info', keep(1 3)


    binscatter cms_payment syssize if syssize > 5, discrete by(year) ///
        legend(row(1)) name(pay_ts) ti("Avg Payment by System Size")
    * graph export $out/cmsprog_syst_pay.png, width(1500) replace
    */

    bys sysid year: gen n = _N
    gen frac_sys_paid = n/syssize
    egen rep_sy = tag(sysid year)
    binscatter frac_sys_paid syssize if rep_sy == 1 & syssize > 5, discrete by(year) ///
        legend(row(1)) ti("% of System Paid") yti("Fraction paid")
    * graph export $out/cmsprog_syst_fracpaid.png, width(1500) replace
    */

    tabout syssize year if rep_sy using $out/cmsprog_tab_syssize_year.tex, ///
        replace style(tex) sum cells(N frac_sys_paid) f(0)
    tabout syssize year if rep_sy using $out/cmsprog_tab_syssize_year_frac.tex, ///
        * replace style(tex) sum cells(mean frac_sys_paid) f(2)
    */
    asdf

    twoway ///
        (kdensity cms_payment if year == 2011 & syssize == 131) ///
        (kdensity cms_payment if year == 2012 & syssize == 131) ///
        (kdensity cms_payment if year == 2013 & syssize == 131) ///
        , legend(lab(1 "2011") lab(2 "2012") lab(3 "2013") row(1)) ///
        ti("Dist of payments w/in HCA (largest)")
    graph export $out/cmsprog_sys131_kdens_time.png, width(1500) replace
end

prog def summ_MU_data
/* It's all equal to 1. */
    use $cms_MU_measures_dta
    tab year
    foreach var of varlist CMS* {
        //tab year, summ(`var')
        qui summ `var' if year <2014, d
        di "`var' p25: `r(p25)'"
    }

    collapse (mean) mean=CMS_cpoe ///
             (p50) p50=CMS_cpoe ///
             (p25) p25=CMS_cpoe ///
             (p75) p75=CMS_cpoe ///
             (sum) sum=CMS_cpoe ///
             (count) count=CMS_cpoe ///
             , by(year)


    twoway connected p25 p50 p75 year, name(first)
    twoway (connected count year) (connected mean year, yaxis(2))
end

*payments_only
payments_by_syssize
