if regexm(c(hostname), "age") {
    global AHA_SRC "/homes/nber/sullivan/healthIT/data/source/aha"
    global DATA_PATH "/homes/nber/sullivan/healthIT/data"
}
else if regexm(c(hostname), "nber") {
    global AHA_SRC "/homes/nber/sullivan/aha.work"
    global DATA_PATH "$AHA_SRC/healthIT/dta"
}
else {
    di as err "NO OR INVALID HOST NAME! I DON'T KNOW WHERE I AM!!!!"
    error 999
}

global OUT_PATH ../out/1505

* Src paths
global HIMSS_SRC "/homes/data/himss"
global COSTREPORT_SRC "/homes/data/hcris"
global HCOMPARE_SRC "$DATA_PATH/source/hospcompare"

* After initial cleaning
global himss_extract "$DATA_PATH/himss-extract"
global himss_panel "$DATA_PATH/himss_panel_full"

global aha_clean_dta "$AHA_SRC/hIT-aha-clean"

global hcompare_coremsr_dta "$DATA_PATH/hcompare_coremsr"
global hcompare_mortality_dta "$DATA_PATH/hcompare_mortality"

global cms_ehr_payments_dta     "$DATA_PATH/cms_ehr_payments"
global cms_MU_measures_dta      "$DATA_PATH/cms_MU_measures"

* Combined data
global combined_dta $DATA_PATH/hIT-combineddata

* Reg ready
global regready_dta $DATA_PATH/hIT-regready

* CMS
*-----

global CMS_SRC "/disk/aging/medicare/data/100pct"

global xwalk_clm_beneid $DATA_PATH/xwalk_clm_beneid
global readmit_flag $DATA_PATH/readmit30_flag

global basic_cms_panel $DATA_PATH/basic_cms_panel

