#! /bin/bash
xstata do analysis/systems_variance.do main_by_ownership
xstata do analysis/systems_variance.do main_by_syssize
xstata do analysis/casestudy_plots.do plot_hosplvl
