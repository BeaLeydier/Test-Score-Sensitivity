/*******************************************************************************

	Output results for round 5 test scores

*******************************************************************************/
	////// Set up //////

clear all
set maxvar 32767	
	
* Load the file paths
do "_filepaths.do"

* Ado path 
adopath ++ "$gituser/ado" 

* Upload raw test scores
use "$dropboxuser/$rawscores/public_child_tests_data_5yrs.dta", clear

* Keep round 5 scores only
keep if year==5

* Count number of items, and keep only the children with the max
egen math_count = anycount(math_item*), values(0 1)
tab math_count
keep if math_count==44

*Drop all the variables that have missing values for everybody
missings dropvars, force

* Keep variables of interest only
keep childcode math_item* math_sum math_count mauzaid child_age child_female 

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

exit
	
	
use "$gituser/1_raw/math-items-5years.dta", clear

gsort -a_eap id
gen discrim_rank = _n
