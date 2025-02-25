/*******************************************************************************

	Different test score gains against the control group growth

*******************************************************************************/
	

	/********************************************

			Set up

	********************************************/
	
	
clear all
	
* Load the file paths
do "_filepaths.do"

* Ado path 
adopath ++ "$gituser/ado" 

* Number of iterations
local iterations 100
local selected 5


	/********************************************

			Bring in Math Item Data
				- Years 1 & 2 
				- Item-Level Data
				- Calculcated Scores from study 

	********************************************/

* Upload raw test scores
use "$dropboxuser/$rawscores/public_child_tests_data_5yrs.dta", clear

* Drop if mauzaid is missing 
drop if mauzaid==.

* Keep years 1 and 2 
keep if year == 1 | year == 2

* Only keep the items common between years 1 and 2 
mdesc math_item* 

** drop items not used in year 1
drop math_item43 math_item44 math_item45 math_item46 math_item47 math_item48 math_item49 math_item50 math_item51 math_item52 math_item53 math_item54 math_item55 

** drop items not used in year 2
drop math_item03 math_item04 math_item05 math_item06 math_item07 math_item08 math_item10 math_item14 math_item17 math_item21 math_item29 math_item35 math_item41 

mdesc math_item*

* Count number of items, and keep only the children with the max
egen math_count = anycount(math_item*), values(0 1)
tab math_count
	//all have exactly 29 items (42 when we include non common items)
	
*Drop all the variables that have missing values for everybody
missings dropvars, force

* Keep variables of interest only
keep year childcode math_item* math_sum math_count mauzaid child_age child_female 

* Add the RCT data 
merge m:1 mauzaid using "$dropboxuser/$RCT/mauzas.dta", nogen

* Add the calculated scores from study 
preserve 
	use "/Users/bl517/Dropbox/LEAPS_ReportCards_2011/2_data_constructed/child_inclr5sibs_wide.dta", clear
	
	rename childuniqueid childcode 
	
	keep childcode total_mle1 math_mle1 total_mle2 math_mle2 child_panel district
	
	reshape long total_mle math_mle, i(childcode) j(year)
	
	tempfile scores
	save `scores'
restore 

merge 1:1 year childcode using `scores'

tab child_panel _merge
drop if _merge==2
drop _merge 


	/********************************************

			Calculate Subsetted Scores 
			
	********************************************/

*Generate the total math scores 
egen mean_math = rowmean(math_item*)			
egen std_math = std(mean_math)	

*Explore 
table reportcard year, stat(mean mean_math std_math math_mle total_mle)

*Number the items consistently
	rename math_item01 math_item1
	rename math_item09 math_item9

* Calculate the math subsets

subsetscore_reg	std_math reportcard if year==2 using "$gituser/img/reg-`selected'items-`iterations'iter.png", selected(`selected') iterations(`iterations') stubname(math_item)

	/*Note : this program saves the results in temp/output.dta */

	/********************************************

			Calculate Control Group Growth
			
	********************************************/

* Only keep relevant variables
keep childcode year std_* math_mle total_mle mauzaid reportcard
	 
* Reshape long at the iteration level 
rename std_math std_5items_0
reshape long std_5items_, i(childcode year)	j(iteration)
	
* Reshape wide for years in column

reshape wide math_mle total_mle std_5items_ mauzaid, j(year) i(childcode iteration)
ren mauzaid1 mauzaid

* Collapse at the group-iteration level
collapse (mean) math_mle1 total_mle1 std_5items_1 math_mle2 total_mle2 std_5items_2, by(reportcard iteration)
label drop childactivity

* Keep the control group 
keep if reportcard==0

* Calculate the diff between Y1 and Y2
gen growth_control = std_5items_2 - std_5items_1

save "$gituser/2_temp/controlgrowth.dta", replace

	/********************************************

			Graph Coeff Estimates Against
			Control Group Growth
			
	********************************************/

use "$gituser/2_temp/output.dta", clear

merge 1:1 iteration using "$gituser/2_temp/controlgrowth.dta", keepusing(growth_control) assert(3) nogen

twoway  (scatter b growth_control if iteration>0, mcolor(navy)) ///			//simulated regs
	(scatter b growth_control if iteration==0, mcolor(gold)) /// 	//reference reg
	, by(var, legend(off) note("") title("Regression Coefficients x Control Group Growth") subtitle("With `iterations' iterations selecting a random subset of `selected' items")) ///
	 ytitle("Regression Coefficient") xtitle("Control Group Growth") 
graph export "$gituser/img/growth-`selected'items-`iterations'iter.png", replace

gen lays = b / abs(growth_control)
sort b

graph box b growth_control lays, legend(position(6) rows(1)) title("Variance on estimates across `iterations' iterations") subtitle("Score from `selected' items") 
graph export "$gituser/img/var-estimates-`selected'items-`iterations'iter.png", replace

graph box b growth_control lays, legend(position(6) rows(1)) title("Variance on estimates across `iterations' iterations") subtitle("Score from `selected' items") nooutsides
graph export "$gituser/img/var-estimates-`selected'items-`iterations'iter-nooutsides.png", replace

//twoway rcap ci_l ci_u iteration || scatter b iteration

