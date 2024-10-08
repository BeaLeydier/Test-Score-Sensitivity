/*******************************************************************************

	Output results for round 5 test scores

*******************************************************************************/
	////// Set up //////

clear all
	
* Load the file paths
do "_filepaths.do"

* Ado path 
adopath ++ "$gituser/ado" 

	////// Upload test scores //////

* Upload raw test scores
use "$dropboxuser/$rawscores/public_child_tests_data_5yrs.dta", clear

* Drop if mauzaid is missing 
drop if mauzaid==.

* Keep years 1 and 2 
keep if year == 1 | year == 2

* Keep only people observed twice
duplicates tag childcode, gen(dup)
drop if dup==0
drop dup

* Count number of items, and keep only the children with the max
egen math_count = anycount(math_item*), values(0 1)
tab math_count
	//all have exactly 42 items 
	
*Drop all the variables that have missing values for everybody
missings dropvars, force

* Keep variables of interest only
keep year childcode math_item* math_sum math_count mauzaid child_age child_female 

* Add the RCT data 
merge m:1 mauzaid using "$dropboxuser/$RCT/mauzas.dta", nogen

*Generate the z score (dev from the mean, IN standard deviations) for each topic
egen math_score = std(math_sum)
		*egen eng_zscore = std(eng_sum)
		*egen urdu_zscore = std(urdu_sum)
		*egen all_zscore = std(allsubjects_sum)

*Number the items consistently
	rename math_item01 math_item1
	rename math_item03 math_item3
	rename math_item09 math_item9

* Gen the school grant variable 
gen schoolgrant = (strata == 2 | strata == 3)	

* Calculate the math subsets

subsetscore_reg	math_score reportcard if year==2, selected(20) iterations(100) stubname(math_item)

exit 
* Store the y1 - y2 growth in control group

local iterations 100
local selected 20

** reshape wide 
local list 
forvalues iter = 1/`iterations' {
	local list `list' std_`selected'items_`iter'
}

foreach var of varlist `list' {
	ren `var' `var'_
}

local toreshape 
forvalues iter = 1/`iterations' {
	local toreshape `toreshape' std_`selected'items_`iter'_
}

keep childcode year math_score `toreshape' mauzaid reportcard

reshape wide math_score `toreshape' mauzaid, j(year) i(childcode)
ren mauzaid1 mauzaid

gen growth_0 = math_score2 - math_score1
forvalues iter = 1/`iterations' {
	gen growth_`iter' = std_`selected'items_`iter'_2 - std_`selected'items_`iter'_1
}

keep childcode reportcard growth*

reshape long growth_, i(childcode) j(iteration)
label drop childactivity

collapse (mean) growth_, by(iteration reportcard)
keep if reportcard==0 
ren growth_ growth_control 

save "$gituser/2_temp/controlgrowth.dta", replace


use "$gituser/2_temp/output.dta", clear

merge 1:1 iteration using "$gituser/2_temp/controlgrowth.dta", keepusing(growth_control) assert(3) nogen

local iterations 100
local selected 20
twoway  (scatter b growth_control if iteration>0, mcolor(navy)) ///			//simulated regs
	(scatter b growth_control if iteration==0, mcolor(gold)) /// 	//reference reg
	, by(var, legend(off) note("") title("Regression Coefficients x Control Group Growth") subtitle("With `iterations' iterations selecting a random subset of `selected' items")) ///
	 ytitle("Regression Coefficient") xtitle("Control Group Growth") 
graph export "$gituser/img/growth-20items.png", replace
