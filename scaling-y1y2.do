/*******************************************************************************

	Create 100 scale transformations
		for years 1 and 2

*******************************************************************************/
	////// Set up //////

* Load the file paths
do "$gituser/_filepaths.do"

* Ado path 
adopath ++ "$gituser/ado" 

* Upload raw test scores
use "$dropboxuser/$public/school/master/public_child_irt_scores_panel.dta", clear

* Keep years 1 and 2
keep if year == 1 | year == 2

* Keep kids tested twice 
duplicates tag childuniqueid, gen(dup)
tab dup
keep if dup==1
drop dup

* Keep score vars of interest 
drop *_pv* 
drop *mle_se
drop district_name
drop *eap

* Gen the average test score
egen total_mle = rowmean(eng_theta_mle math_theta_mle urdu_theta_mle)

* Ren test score vars
foreach var of varlist *_theta_mle {
	local varname = "`var'"
	local newname = subinstr("`varname'", "theta_", "", .)
	rename `var' `newname'
}

* Reshape scores wide
drop childcode hhid mid
reshape wide district mauzaid schoolid total_mle eng_mle math_mle urdu_mle, i(childuniqueid) j(year)

* Use the round 1 district/mauza for treatment assignment value
ren district1 district
ren mauzaid1 mauzaid 
ren schoolid1 schoolid 

* Merge in reportcard info 
merge m:1 mauzaid using "$dropboxuser/$RCT/mauzas.dta", assert(3 2) keep(3)

* Save the test scores transformed data 
save "$gituser/2_build/testcores_y1y2_wide.dta", replace


* Scale transformation : max gap

use "$gituser/2_build/testcores_y1y2_wide.dta", clear

scale_transformation, type(1) score1(total_mle1) score2(total_mle2) compgroup(reportcard) iterations(100) robust(20) monotonicity(2) save("$gituser/scaling/iterations100-y2-max.dta") //28minutes run time 


* Scale transformation : min gap

use "$gituser/2_build/testcores_y1y2_wide.dta", clear

scale_transformation, type(2) score1(total_mle1) score2(total_mle2) compgroup(reportcard) iterations(100) robust(20) monotonicity(2) save("$gituser/scaling/iterations100-y2-min.dta")

* Scale transformation : max correlation

use "$gituser/2_build/testcores_y1y2_wide.dta", clear

scale_transformation, type(3) score1(total_mle1) score2(total_mle2) iterations(100) monotonicity(2) save("$gituser/scaling/iterations100-y2-corr.dta")

* Scale transformation : max r2

use "$gituser/2_build/testcores_y1y2_wide.dta", clear

scale_transformation, type(5) score1(total_mle1) score2(total_mle2) iterations(100) monotonicity(2) save("$gituser/scaling/iterations100-y2-r2.dta")
