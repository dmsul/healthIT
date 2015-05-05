#! /bin/bash
# `payment_outliers`, list of really bad predictions
xstata do analysis/compare_ourIT_to_CMS.do
xstata do analysis/summ_cms_ehr_data.do
xstata do analysis/system_adoption.do 
xstata do analysis/systems_variance.do
