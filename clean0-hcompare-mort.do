/*
   This file constructs a panel for MORTALITY AND READMISSIONS from the Hospital Compare dataset.
   
   3/09 (2007_ann?):
      providerid
      hosp_name
      condition
      measure_label
      category
      score
      score_loCI
      score_hiCI
      sample_size
      footnote
   6/09 (2007_ann?): (same as 3/09)
   
   3/10 (2008_trian):
      providerid
      hosp_name
      condition
      measure_label // Starting here, mortality or readmit
      category
      score
      score_loCI
      score_hiCI
      sample_size
      footnote

   12/10 (2009_trian):
      providerid
      hosp_name
      state
      condition
      measure_label // Starting here, mortality or readmit
      score
      score_loCI
      score_hiCI
      sample_size
      footnote
      
   8/11 (2010_trian):
      providerid
      hosp_name
      state
      condition
      measure_label // Starting here, mortality or readmit
      score
      category
      score_loCI
      score_hiCI
      sample_size
      footnote
      
   4/2013 (2011_trian):
      providerid
      hosp_name
      condition
      measure_label // Starting here, mortality or readmit
      score
      category
      score_loCI
      score_hiCI
      sample_size
      footnote
      state
      
   4/2014 (2011_trian):
      providerid
      hosp_name
      state
      condition
      measure_label // Starting here, mortality or readmit
      score
      category
      score_loCI
      score_hiCI
      sample_size
      footnote
      
      
*/
clear all

run src/globals

global SRCROOT $HCOMPARE_SRC
global OUT_MORTALITY $hcompare_mortality_dta


tempfile base
save `base', emptyok

**********
insheet hosp_id hosp_name condition measure_label category score score_loCI score_hiCI sample footnote using $SRCROOT/dbo_vwHQI_HOSP_MORTALITY_XWLK_d200903.txt, clear
gen year = 2007

drop footnote

tostring hosp_id, replace
replace hosp_id = "0" + hosp_id if length(hosp_id)<6
assert length(hosp_id)==6

append using `base'
save `base', replace   

**********
insheet hosp_id hosp_name condition measure_label category score score_loCI score_hiCI sample footnote using $SRCROOT/dbo_vwHQI_HOSP_MORTALITY_READM_XWLK_d201003.txt, clear
gen year = 2008

drop footnote

tostring hosp_id, replace
replace hosp_id = "0" + hosp_id if length(hosp_id)<6
assert length(hosp_id)==6

append using `base'
save `base', replace   

**********
insheet hosp_id hosp_name state condition measure_label score score_loCI score_hiCI sample footnote using $SRCROOT/dbo_vwHQI_HOSP_MORTALITY_READM_XWLK_d201012.txt, clear
gen year = 2009

drop footnote

replace hosp_id = subinstr(hosp_id,"'","",.)
destring score* sample, i("N/A") replace

append using `base'
save `base', replace   

**********
insheet hosp_id hosp_name state condition measure_label score category score_loCI score_hiCI sample footnote using $SRCROOT/dbo_vwHQI_HOSP_MORTALITY_READM_XWLK_d201108.txt, clear
gen year = 2010

drop footnote

replace hosp_id = subinstr(hosp_id,"'","",.)
destring score* sample, i("N/A") replace

tostring hosp_id, replace
replace hosp_id = "0" + hosp_id if length(hosp_id)<6
assert length(hosp_id)==6

append using `base'
save `base', replace   

**********
insheet hosp_id hosp_name condition measure_label score category score_loCI score_hiCI sample footnote state using $SRCROOT/dbo_vwHQI_HOSP_MORTALITY_READM_XWLK_d201304.csv, clear
drop if condition=="Condition"
gen year = 2011

drop footnote

destring score* sample, i("Not Available") replace
replace hosp_id = subinstr(hosp_id,"'","",.)
tostring hosp_id, replace
replace hosp_id = "0" + hosp_id if length(hosp_id)<6
assert length(hosp_id)==6

append using `base'
save `base', replace

**********
import excel hosp_id hosp_name state condition measure_label score category ///
            score_loCI score_hiCI sample footnote ///
            using $SRCROOT/dbo_vwHQI_HOSP_MORTALITY_READM_XWLK_d201404.xlsx, ///
            clear
drop if condition=="Condition"
gen year = 2012

drop footnote

destring score* sample, i("Not Available") replace
replace hosp_id = subinstr(hosp_id,"'","",.)
tostring hosp_id, replace
replace hosp_id = "0" + hosp_id if length(hosp_id)<6
assert length(hosp_id)==6

append using `base'
save `base', replace

gen measure = ""
replace measure = "pn_mort" if regexm(measure_label,"neumonia") & regexm(measure_label,"ortality")
replace measure = "pn_read" if regexm(measure_label,"neumonia") & regexm(measure_label,"eadmis")

replace measure = "ha_mort" if regexm(measure_label,"ttack") & regexm(measure_label,"ortality")
replace measure = "ha_read" if regexm(measure_label,"ttack") & regexm(measure_label,"eadmis")

replace measure = "hf_mort" if regexm(measure_label,"ailure") & regexm(measure_label,"ortality")
replace measure = "hf_read" if regexm(measure_label,"ailure") & regexm(measure_label,"eadmis")

drop if measure==""

keep hosp_id score sample year measure
egen hospyr = group(hosp_id year)

reshape wide score sample, i(hospyr) j(measure) string
drop hospyr

foreach diag in pn ha hf {
   foreach metric in mort read {
      ren score`diag'_`metric' `diag'_`metric'
      ren sample`diag'_`metric' `diag'_`metric'_N
   }
}

/*
reshape wide pn* ha* hf*, i(hosp_id) j(year)

foreach var in pn_mort pn_read ha_mort ha_read hf_mort hf_read {
   foreach y in 2008 2009 2010 2011 {
      ren `var'`y' `var'_tri`y'
   }
   gen `var'2008 = 3*`var'_tri2008 - 2*`var'2007
   gen `var'2009 = 3*`var'_tri2009 - `var'2008 - `var'2007
   gen `var'2010 = 3*`var'_tri2010 - `var'2009 - `var'2008
   gen `var'2011 = 3*`var'_tri2011 - `var'2010 - `var'2009
}

reshape long /// 
   pn_mort pn_mort_tri pn_read pn_read_tri pn_mort_N pn_read_N /// 
   hf_mort hf_mort_tri hf_read hf_read_tri hf_mort_N hf_read_N ///
   ha_mort ha_mort_tri ha_read ha_read_tri ha_mort_N ha_read_N ///
          , i(hosp_id) j(year)

drop pn_read ha_read hf_read
*/

compress
save $OUT_MORTALITY, replace

