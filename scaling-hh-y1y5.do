/*******************************************************************************

	Create 100 scale transformations
		for years 1 and 5

*******************************************************************************/
	////// Set up //////

* Load the file paths
do "$gituser/_filepaths.do"

* Ado path 
adopath ++ "$gituser/ado" 

* Upload the 2011 household sample 
use "/Users/bl517/Dropbox/LEAPS_RCT_2011/2_data_constructed/20240617_leaps.dta", clear

* Keep years 1 and 5 
keep if year == 1 | year == 5

* Keep kids that were tested 
keep if eng_theta_mle_se != .

* Keep kids tested twice 
duplicates tag uniqueid_num, gen(dup)
tab dup
keep if dup==1
drop dup

* Keep score vars of interest 
keep uniqueid_num year mauzaid district age_imp male eng_theta_mle math_theta_mle urdu_theta_mle child_panel school_code schooltype reportcard strata total_irt testscore_yn tag0020_2allyrs tag0612_2allyrs tag0005_2allyrs tag0012_2allyrs

* Ren test score vars
foreach var of varlist *_theta_mle {
	local varname = "`var'"
	local newname = subinstr("`varname'", "theta_", "", .)
	rename `var' `newname'
}

* Reshape scores wide
reshape wide age_imp eng_mle math_mle urdu_mle school_code schooltype testscore_yn total_irt, i(uniqueid_num) j(year)


* Save the test scores transformed data 
save "$gituser/2_build/testcores_hh_y1y5_wide.dta", replace


* Scale transformation : max gap

use "$gituser/2_build/testcores_hh_y1y5_wide.dta", clear

scale_transformation, type(1) score1(total_irt1) score2(total_irt5) compgroup(reportcard) iterations(100) robust(20) monotonicity(2) save("$gituser/scaling/iterations100-hh-y5-max.dta") //28minutes run time 


* Scale transformation : min gap

use "$gituser/2_build/testcores_hh_y1y5_wide.dta", clear

scale_transformation, type(2) score1(total_irt1) score2(total_irt5) compgroup(reportcard) iterations(100) robust(20) monotonicity(2) save("$gituser/scaling/iterations100-hh-y5-min.dta")

* Scale transformation : max correlation

use "$gituser/2_build/testcores_hh_y1y5_wide.dta", clear

scale_transformation, type(3) score1(total_irt1) score2(total_irt5) iterations(100) monotonicity(2) save("$gituser/scaling/iterations100-hh-y5-corr.dta")

* Scale transformation : max r2

use "$gituser/2_build/testcores_hh_y1y5_wide.dta", clear

scale_transformation, type(5) score1(total_irt1) score2(total_irt5) iterations(100) monotonicity(2) save("$gituser/scaling/iterations100-hh-y5-r2.dta")
