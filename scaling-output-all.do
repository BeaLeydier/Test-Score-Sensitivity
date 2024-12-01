/*******************************************************************************

	Create output from scale transformations

*******************************************************************************/

	////// Set up //////

* Load the file paths
do "$gituser/_filepaths.do"

* Ado path 
adopath ++ "$gituser/ado" 

* Define endline year
local endyear 2

* Define n of iterations
local iter 500

* Define subject (for iterations file name)
local subject math-

* Define subject (for test score variable name)
local subj math

/*******************************************************************************

	Save coefficients for optimized scale transformations found

*******************************************************************************/

// Max gap growth between T and C

* Load the output from the scale transformation
use "$gituser/scaling/`subject'iterations`iter'-y`endyear'-max.dta", clear

* Keep only the observations that are order preserving
keep if obj != .

* Place the bigger obj first 
gsort - obj

* Keep the highest one only
keep if _n == 1 

* Identify the type of transformation 
gen type = "max"

* Save tempfile 
tempfile max 
save `max'

/// Min gap growth between T and C 

* Load the output from the scale transformation
use "$gituser/scaling/`subject'iterations`iter'-y`endyear'-min.dta", clear

* Keep only the observations that are order preserving
keep if obj != .

* Place the smaller obj first 
sort obj

* Keep the highest one only
keep if _n == 1 

* Identify the type of transformation 
gen type = "min"

* Save tempfile 
tempfile min 
save `min'

/// Max correlation between years 1 and years `endyear' 

* Load the output from the scale transformation
use "$gituser/scaling/`subject'iterations`iter'-y`endyear'-corr.dta", clear

* Keep only the observations that are order preserving
keep if obj != .

* Place the bigger obj first 
gsort - obj

* Keep the highest one only
keep if _n == 1 

* Identify the type of transformation 
gen type = "corr"

* Save tempfile 
tempfile corr 
save `corr'

/// Max r2 between years 1 and years `endyear'

* Load the output from the scale transformation
use "$gituser/scaling/`subject'iterations`iter'-y`endyear'-r2.dta", clear

* Keep only the observations that are order preserving
keep if obj != .

* Place the bigger obj first 
gsort - obj

* Keep the highest one only
keep if _n == 1 

* Identify the type of transformation 
gen type = "r2"

* Save tempfile 
tempfile r2 
save `r2'


/// Append all types 

* Append
use `max', clear
append using `min'
append using `corr'
append using `r2'

* Reshape wide 
drop init_* 
foreach var of varlist obj b1 b2 b3 b4 b5 b6 c {
	ren `var' `var'_
}
gen obs = 1
reshape wide obj b1 b2 b3 b4 b5 b6 c, j(type) i(obs) string

* Save
tempfile coefs
save `coefs'



/*******************************************************************************

	Add these coefficiients to the test score data 
	
*******************************************************************************/


* Load test scores
use "$gituser/2_build/testcores_y1y`endyear'_wide.dta", clear 

* Merge the polynomial transformations outputed from the command
gen obs = 1
merge m:1 obs using `coefs', nogen assert(3)
 
* Calculate the new testscores
foreach i in max min corr r2 {
	foreach year in 1 `endyear' {
		gen `subj'_mle`year'_`i' =  b1_`i' * (`subj'_mle`year' - c_`i') + ///
			b2_`i' * (`subj'_mle`year' - c_`i')^2 + b3_`i' * (`subj'_mle`year' - c_`i')^3 + /// 
			b4_`i' * (`subj'_mle`year' - c_`i')^4 + b5_`i' * (`subj'_mle`year' - c_`i')^5 + /// 
			b6_`i' * (`subj'_mle`year' - c_`i')^6  	
	}
}

* Drop the polynomial transformation coefficients
drop b*_* c_*

* Standardize the new test scores (periods 1 and `endyear' combined)
*** step 1 : list the variables to reshape
local varlist 
foreach i in max min corr r2 {
	local varlist `varlist' `subj'_mle@_`i'
}
gl vartoreshape `varlist'

*** step 2 : reshape at the individual-year level 
reshape long `subj'_mle@ $vartoreshape, i(childuniqueid) j(year)

*** step 3 : standardize 
foreach i in max min corr r2 {
	egen `subj'_mle_`i'_std = std(`subj'_mle_`i')
}

* Save new file 
save "$gituser/2_build/testcores_y1y`endyear'_rescaled_`subject'`iter'.dta", replace 


/*******************************************************************************

	Create correlation matrix 
	
*******************************************************************************/


// Generate correlation matrix
correlate `subj'_mle `subj'_mle_max_std `subj'_mle_min_std `subj'_mle_corr_std `subj'_mle_r2_std

// store results
matrix C = r(C)

// Create heatmap
heatplot C, color(hcl diverging, intensity(.6)) ///
    cuts(-1(.2)1) backfill ///
    legend(subtitle("Correlation")) ///
    xlabel(, angle(45) labsize(small)) ///
    ylabel(, angle(0) labsize(small)) ///
    title("Correlation Heatmap")	
graph export "$gituser/img/rescaled-corr-y`endyear'_`subject'`iter'.png", as(png) name("Graph") replace	 
	

/*******************************************************************************

	Plot lagged regression 
	
*******************************************************************************/


* Calculate and plot all the regressions 

	* Create panel 
	xtset childuniqueid year
	sort childuniqueid year
	
	* Clear the eststo 
	eststo clear 
	
	* Create the lag year 
	local lag = `endyear' - 1	
	
	* Run the normal reg
	eststo eqog: reg `subj'_mle reportcard i.district L`lag'.`subj'_mle if year==`endyear', vce(cluster mauzaid)

	* Run the reg with the created variables
	foreach i in max min corr r2 {
		eststo eq`i': reg  `subj'_mle_`i'_std reportcard i.district L`lag'.`subj'_mle_`i'_std if year==`endyear', vce(cluster mauzaid)
	}
	
	* Store the regression values
	estout _all, cells("b(fmt(%9.3f)) se(fmt(%9.3f)) p(fmt(%9.3f)) ci_l(fmt(%9.3f)) ci_u(fmt(%9.3f))") stats(N r2) 

	mat A = r(coefs)
	mat B = r(stats)

	* Store the regression stats (N and r2)
	preserve
		clear 
		svmat B, names(eqcol)

		local statnames : rownames B
		gen stat=""
		forvalues i=1/`: word count `statnames'' {
		  replace stat=`"`: word `i' of `statnames''"' in `i'
		}

		gen i = "stat"

		reshape wide _eq*, j(stat) i(i) string 

		reshape long _eq@N _eq@r2, i(i) j(iteration) string
		drop i 
		
		foreach var of varlist _all {
			local varname = "`var'"
			local newname = subinstr("`varname'", "_eq", "", .)
			rename `var' `newname'
		}
		
		tempfile stats 
		save `stats'
	restore  

	* Store the regression coefficients 
	preserve 
		clear 
		svmat A, names(eqcol)

		local coefnames : rownames A
		gen var=""
		forvalues i=1/`: word count `coefnames'' {
		  replace var=`"`: word `i' of `coefnames''"' in `i'
		}

		reshape long eq@b eq@se eq@p eq@ci_l eq@ci_u, i(var) j(iteration) string
			
		* Add the regression stats to them	
		merge m:1 iteration using `stats', assert(3) nogen	
			
		foreach var in eqb eqse eqp eqci_l eqci_u {
			local varname = "`var'"
			local newname = subinstr("`varname'", "eq", "", .)
			rename `var' `newname'
		}

		* Only keep the relevant coefficients for plotting 
		if `lag' == 1 {
			replace var = "L.`subj'_mle" if var == "L.`subj'_mle_corr_std" 
			replace var = "L.`subj'_mle" if var == "L.`subj'_mle_max_std" 
			replace var = "L.`subj'_mle" if var == "L.`subj'_mle_min_std" 
			replace var = "L.`subj'_mle" if var == "L.`subj'_mle_r2_std" 			
			local keep reportcard L.`subj'_mle
		} 
		else {
			replace var = "L`lag'.`subj'_mle" if var == "L`lag'.`subj'_mle_corr_std" 
			replace var = "L`lag'.`subj'_mle" if var == "L`lag'.`subj'_mle_max_std" 
			replace var = "L`lag'.`subj'_mle" if var == "L`lag'.`subj'_mle_min_std" 
			replace var = "L`lag'.`subj'_mle" if var == "L`lag'.`subj'_mle_r2_std" 
			local keep reportcard L`lag'.`subj'_mle
		}
		
		keep if strpos("`keep'", var) > 0
		
		* Gen the iteration id for x axis 
		sort b
		gen x = _n
		
		drop if b == .z
		
		* Plot the regression coefficients and their CI 		
		twoway  (scatter b x if iteration=="og", mcolor(gold)) (rcap ci_l ci_u x if iteration=="og", lcolor(gold)) /// 	//reference reg
			(scatter b x if iteration=="max", mcolor(cranberry)) (rcap ci_l ci_u x if iteration=="max", lcolor(cranberry)) /// 	//maximizing gap growth reg
			(scatter b x if iteration=="min", mcolor(navy)) (rcap ci_l ci_u x if iteration=="min", lcolor(navy)) /// 	//minimizing gap growth reg
			(scatter b x if iteration=="corr", mcolor(lime)) (rcap ci_l ci_u x if iteration=="corr", lcolor(lime)) /// 	//max corr 
			(scatter b x if iteration=="r2", mcolor(purple)) (rcap ci_l ci_u x if iteration=="r2", lcolor(purple)) /// 	//max r2 
			, by(var, legend(off) title("Regression (on Y`endyear' `subj' test scores) Coefficients") note("Yellow = original test score." "Red = test scores maximizing the y1-y`endyear' gap growth between T and C." "Blue = test scores minimizing the y1-y`endyear' gap growth between T and C." "Lime = test scores maximizing correlation between y1 and y`endyear'. Purple = test scores maximizing the R2 between y1 and y`endyear'.")) ///
			 ytitle("Regression Coefficient") xtitle("") yline(0) xlabel(none) 
		graph export "$gituser/img/rescaled-regression-lagged-y`endyear'`subject'`iter'.png", as(png) name("Graph") replace
				
	restore

	


/*******************************************************************************

	Plot regression 
	
*******************************************************************************/

	
* Calculate and plot all the regressions 

	* Create panel 
	xtset childuniqueid year
	sort childuniqueid year
	
	* Clear the eststo 
	eststo clear 
		
	* Run the normal reg
	eststo eqog: reg `subj'_mle reportcard i.district if year==`endyear', vce(cluster mauzaid)

	* Run the reg with the created variables
	foreach i in max min corr r2 {
		eststo eq`i': reg  `subj'_mle_`i'_std reportcard i.district if year==`endyear', vce(cluster mauzaid)
	}
	
	* Store the regression values
	estout _all, cells("b(fmt(%9.3f)) se(fmt(%9.3f)) p(fmt(%9.3f)) ci_l(fmt(%9.3f)) ci_u(fmt(%9.3f))") stats(N r2) 

	mat A = r(coefs)
	mat B = r(stats)

	* Store the regression stats (N and r2)
	preserve
		clear 
		svmat B, names(eqcol)

		local statnames : rownames B
		gen stat=""
		forvalues i=1/`: word count `statnames'' {
		  replace stat=`"`: word `i' of `statnames''"' in `i'
		}

		gen i = "stat"

		reshape wide _eq*, j(stat) i(i) string 

		reshape long _eq@N _eq@r2, i(i) j(iteration) string
		drop i 
		
		foreach var of varlist _all {
			local varname = "`var'"
			local newname = subinstr("`varname'", "_eq", "", .)
			rename `var' `newname'
		}
		
		tempfile stats 
		save `stats'
	restore  

	* Store the regression coefficients 
	preserve 
		clear 
		svmat A, names(eqcol)

		local coefnames : rownames A
		gen var=""
		forvalues i=1/`: word count `coefnames'' {
		  replace var=`"`: word `i' of `coefnames''"' in `i'
		}

		reshape long eq@b eq@se eq@p eq@ci_l eq@ci_u, i(var) j(iteration) string
			
		* Add the regression stats to them	
		merge m:1 iteration using `stats', assert(3) nogen	
			
		foreach var in eqb eqse eqp eqci_l eqci_u {
			local varname = "`var'"
			local newname = subinstr("`varname'", "eq", "", .)
			rename `var' `newname'
		}

		
		local keep reportcard 
		keep if strpos("`keep'", var) > 0
		
		* Gen the iteration id for x axis 
		sort b
		gen x = _n
		
		drop if b == .z
		
		* Plot the regression coefficients and their CI 		
		twoway  (scatter b x if iteration=="og", mcolor(gold)) (rcap ci_l ci_u x if iteration=="og", lcolor(gold)) /// 	//reference reg
			(scatter b x if iteration=="max", mcolor(cranberry)) (rcap ci_l ci_u x if iteration=="max", lcolor(cranberry)) /// 	//maximizing gap growth reg
			(scatter b x if iteration=="min", mcolor(navy)) (rcap ci_l ci_u x if iteration=="min", lcolor(navy)) /// 	//minimizing gap growth reg
			(scatter b x if iteration=="corr", mcolor(lime)) (rcap ci_l ci_u x if iteration=="corr", lcolor(lime)) /// 	//max corr 
			(scatter b x if iteration=="r2", mcolor(purple)) (rcap ci_l ci_u x if iteration=="r2", lcolor(purple)) /// 	//max r2 
			, by(var, legend(off) title("Regression (on Y`endyear' test scores) Coefficients") note("Yellow = original test score." "Red = test scores maximizing the y1-y`endyear' gap growth between T and C." "Blue = test scores minimizing the y1-y`endyear' gap growth between T and C." "Lime = test scores maximizing correlation between y1 and y`endyear'. Purple = test scores maximizing the R2 between y1 and y`endyear'.")) ///
			 ytitle("Regression Coefficient") xtitle("") yline(0) xlabel(none) 
		graph export "$gituser/img/rescaled-regression-y`endyear'`subject'`iter'.png", as(png) name("Graph") replace
				
	restore

		