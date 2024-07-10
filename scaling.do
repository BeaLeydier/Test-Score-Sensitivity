/*******************************************************************************

	Create z-scores for round 5 tests

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

* Keep only people observed twice
duplicates tag childuniqueid, gen(dup)
drop if dup==0
drop dup

* Reshape scores wide
reshape wide district mauzaid schoolid total_mle eng_mle math_mle urdu_mle, i(childuniqueid) j(year)

* Use the round 1 district/mauza for treatment assignment value
ren district1 district
ren mauzaid1 mauzaid 
ren schoolid1 schoolid

* Merge in reportcard info 
merge m:1 mauzaid using "$dropboxuser/$RCT/mauzas.dta", assert(3) nogen

* Scale transformation 
scale_transformation, type(1) score1(total_mle1) score2(total_mle2) compgroup(reportcard) iterations(10) save("$gituser/scaling/iterations10.dta")
