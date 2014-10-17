/*
   This file constructs a panel for "core" from the Hospital Compare dataset.
   
   3/06--3/10 cover July -2 to June -1 respectively
   
   3/06--3/09:
      providerid
      hosp_name
      condition
      measure_label
      score
      sample_size
      footnote
   3/10:
      providerid
      hosp_name
      condition
      measure
      measure_label
      score
      sample_size
      footnote
      
   8/11 (**Oct 09 - Sept 10**), 
   05/2012 (July 10 - June 11), 
   04/2013 (July 11 - June 12) :
      providerid
      hosp_name
      state
      condition
      measure
      measure_label
      score
      sample_size
      footnote   
*/

set more off
clear all

run src/globals

* I/O
*-----
global SRCROOT $HCOMPARE_SRC
global OUT_CORE $hcompare_coremsr_dta


prog def make_panel
    tempfile base
    save `base', emptyok

    // Initial variable list
    foreach release in 200603 200703 200804 200903 {
        di "****** RELEASE `release'**********"
        insheet hosp_id hosp_name condition measure_label score sample_size footnote using $SRCROOT/dbo_vwHQI_HOSP_MSR_XWLK_d`release'.txt, clear
        destring score, replace i("%")
        destring sample, replace i(" patients")
        gen year = real(substr("`release'",1,4)) - 1

        append using `base'
        save `base', replace

    }

    // Change in variable list
    local release 201003
    di "****** RELEASE `release'**********"
    insheet hosp_id hosp_name condition measure measure_label score sample_size footnote using $SRCROOT/dbo_vwHQI_HOSP_MSR_XWLK_d`release'.txt, clear
    destring score, replace i("%")
    destring sample, replace i(" patients")
    gen year = real(substr("`release'",1,4)) - 1

    append using `base'
    save `base', replace

    * Make hosp_id string again with leading zeros
    tostring hosp_id, replace
    replace hosp_id = "0" + hosp_id if length(hosp_id)<6
    assert length(hosp_id)==6

    save `base', replace


    // Another change in variable list
    foreach release in 201108 201205 {
        di "****** RELEASE `release'**********"

        local ext txt

        insheet hosp_id hosp_name state condition measure measure_label score sample_size footnote using $SRCROOT/dbo_vwHQI_HOSP_MSR_XWLK_d`release'.`ext', clear
        replace hosp_id = subinstr(hosp_id,"'","",.)
        destring score, replace i("%N/A")
        destring sample, replace i(" patientsN/A")
        gen year = real(substr("`release'",1,4)) - 1 

        append using `base'
        save `base', replace

    }

    foreach release in 201304 201404 {
        di "****** RELEASE `release'**********"

        local varlist hosp_id hosp_name state condition measure measure_label ///
            score sample_size footnote using 

        if "`release'"=="201304" {
            insheet `varlist' $SRCROOT/dbo_vwHQI_HOSP_MSR_XWLK_d`release'.csv, ///
               clear nonames
        }
        else {
            import excel `varlist' $SRCROOT/dbo_vwHQI_HOSP_MSR_XWLK_d`release'.xlsx, ///
               clear
        }

        drop if hosp_id=="Provider Number"
        replace hosp_id = subinstr(hosp_id,"'","",.)


        destring score, replace i("Not AvailableToofewcases")
        destring sample, replace i("Not AvailableToofewcasesApplicable")
        gen year = real(substr("`release'",1,4)) - 1 

        *replace score = score/10 if score>100
        // check for guys who have 100 but should have 10.0 according to trend? Source file is also missing decimals. Not all the "scores" are percentages. Oops.

        append using `base'
        save `base', replace

    }

    replace measure = trim(measure)
    replace measure = subinstr(measure,"-","",.)
    replace measure = subinstr(measure,"_","",.)
    replace measure_label = lower(measure_label)
    replace measure = lower(measure)
    save $DATA_PATH/temp, replace
end

prog def label_measures
    use $DATA_PATH/temp, clear

    gen oldlabel = measure_label

    replace measure_label = lower(condition) + " " + measure_label

    /*
      Write a 'xwalk' for the early measure labels. Note that outpatient "OP-" 
      measures don't exist in early data and "thrombolytics", "oxygenation", 
      "beta blockers at arrival" and "left ventricular assessment" don't exist 
      in late data. Therefore, these are discarded for now (July 15, 2013)
    */
    gen newmsr = ""
    replace newmsr = "ami1" if regexm(measure_label,"attack") & regexm(measure_label, "aspirin") & regexm(measure_label,"arrival") & !regexm(measure_label,"outpatient")
    replace newmsr = "ami2" if regexm(measure_label,"attack") & regexm(measure_label, "aspirin") & regexm(measure_label,"discharge") & !regexm(measure_label,"outpatient")
    replace newmsr = "ami3" if regexm(measure_label,"attack") & regexm(measure_label, "ace inhibitor")
    replace newmsr = "ami4" if regexm(measure_label,"attack") & regexm(measure_label, "smoking")
    replace newmsr = "ami5" if regexm(measure_label,"attack") & regexm(measure_label, "beta") & regexm(measure_label,"discharge")
    replace newmsr = "ami7a" if regexm(measure_label,"attack") & regexm(measure_label, "fibrinolytic")
    replace newmsr = "ami8a" if regexm(measure_label,"attack") & regexm(measure_label, "pci")
    replace newmsr = "ami10" if regexm(measure_label,"attack") & regexm(measure_label, "statin")
    replace newmsr = "cac1" if regexm(measure_label,"children") & regexm(measure_label, "reliever")
    replace newmsr = "cac2" if regexm(measure_label,"children") & regexm(measure_label, "corticosteroid")
    replace newmsr = "cac3" if regexm(measure_label,"children") & regexm(measure_label, "home manage")
    replace newmsr = "hf1" if regexm(measure_label,"heart failure") & regexm(measure_label, "instructions")
    replace newmsr = "hf2" if regexm(measure_label,"heart failure") & regexm(measure_label, "evaluation")
    replace newmsr = "hf3" if regexm(measure_label,"heart failure") & regexm(measure_label, "ace inhib")
    replace newmsr = "hf4" if regexm(measure_label,"heart failure") & regexm(measure_label, "smoking")
    replace newmsr = "pn2" if regexm(measure_label,"pneumonia") & regexm(measure_label, "pneumococcal")
    replace newmsr = "pn3b" if regexm(measure_label,"pneumonia") & regexm(measure_label, "culture")
    replace newmsr = "pn4" if regexm(measure_label,"pneumonia") & regexm(measure_label, "smoking")
    replace newmsr = "pn5c" if regexm(measure_label,"pneumonia") & regexm(measure_label, "initial") & regexm(measure_label,"within")
    replace newmsr = "pn6" if regexm(measure_label,"pneumonia") & regexm(measure_label, "initial") & regexm(measure_label,"appropriate")
    replace newmsr = "pn7" if regexm(measure_label,"pneumonia") & regexm(measure_label, "influenza")
    replace newmsr = "scipcard2" if regexm(measure_label,"surgery") & regexm(measure_label, "beta")
    replace newmsr = "scipinf1" if regexm(measure_label,"surgery") & regexm(measure_label, "antibiotic") & regexm(measure_label,"before") & !regexm(measure_label,"outpatient")
    replace newmsr = "scipinf2" if regexm(measure_label,"surgery") & regexm(measure_label, "antibiotic") & (regexm(measure_label,"kind") | regexm(measure_label,"appropriate")) & !regexm(measure_label,"outpatient")
    replace newmsr = "scipinf3" if regexm(measure_label,"surgery") & regexm(measure_label, "antibiotic") & regexm(measure_label,"after")
    replace newmsr = "scipinf4" if regexm(measure_label,"surgery") & regexm(measure_label, "sugar")
    replace newmsr = "scipinf6" if regexm(measure_label,"surgery") & regexm(measure_label, "hair")
    replace newmsr = "scipinf10" if regexm(measure_label,"surgery") & regexm(measure_label, "warmed")
    replace newmsr = "scipvte1" if regexm(measure_label,"surgery") & regexm(measure_label, "clots") & regexm(measure_label, "order")
    replace newmsr = "scipvte2" if regexm(measure_label,"surgery") & regexm(measure_label, "clots") & regexm(measure_label,"time")

    replace measure = newmsr if measure==""
    drop newmsr oldlabel footnote condition state hosp_name
    compress
    save $DATA_PATH/temp, replace
end

prog def reshape_rename
    use $DATA_PATH/temp

    *Reshape so unit of obs is hospital--year
    rename sample sample
    egen hospyr = group(hosp_id year)
    drop if measure==""
    drop measure_label

    reshape wide score sample, i(hospyr) j(measure) string
    order hosp_id year


    /*
    // NOTE: This global omits several measures that don't exist in the full panel.
    global MSRLIST ami1 ami2 ami3 ami4 ami5 ami8a hf1 hf2 hf3 hf4 pn2 pn3b pn5c pn6 pn7 scipinf1 scipinf2 scipinf3 scipvte1

    */
    drop hospyr

    foreach var of varlist score* {
        local newname = subinstr("`var'","score","",.) // + "_score"
        rename `var' `newname'
    }
    foreach var of varlist sample* {
        local newname = subinstr("`var'","sample","",.) + "_N"
        rename `var' `newname'
    }
end

make_panel
label_measures
reshape_rename

save $OUT_CORE, replace

