** Program with regression estimates

program define subsetscore_reg

	syntax varlist [if] [fweight  aweight  pweight  iweight], SELECTed(integer) ITERations(integer) STUBname(namelist max=1 local) [keep(varlist)]
		
	* Extrat the Y variable from the varlist, and the X vars from the varlist
	local yvar : word 1 of `varlist'		
	local xvars : list varlist - yvar
	
	* Default value is keep is not specified
	if "`keep'" == "" local keep = "`xvars'"

	* Create the data simulations
	selectitems_data `stubname', selected(`selected') iterations(`iterations')
	
	* Clear the eststo 
	eststo clear 
	
	* Run the normal reg
	eststo eq0: reg `varlist' `if' [`weight' `exp']

	* Run the reg with the created variables
	forvalues i = 1/`iterations' {
		eststo eq`i': reg  std_`selected'items_`i' `xvars' `if' [`weight' `exp']
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

		reshape long _eq@N _eq@r2, i(i) j(iteration)
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

		reshape long eq@b eq@se eq@p eq@ci_l eq@ci_u, i(var) j(iteration)
			
		* Add the regression stats to them	
		merge m:1 iteration using `stats', assert(3) nogen	
			
		foreach var in eqb eqse eqp eqci_l eqci_u {
			local varname = "`var'"
			local newname = subinstr("`varname'", "eq", "", .)
			rename `var' `newname'
		}

		* Only keep the relevant coefficients for plotting 
		keep if strpos("`keep'", var) > 0
		
		* Plot the regression coefficients and their CI 		
		twoway  (scatter b iteration if iteration==0, mcolor(gold)) (rcap ci_l ci_u iteration if iteration==0, lcolor(gold)) /// 	//reference reg
			(scatter b iteration if iteration>0, mcolor(navy)) (rcap ci_l ci_u iteration if iteration>0, lcolor(navy)) ///			//simulated regs
			, by(var, legend(off) title("Regression Coefficients On Different Calculated Scores") subtitle("With `iterations' iterations selecting a random subset of `selected' items")) ///
			 ytitle("Regression Coefficient") xtitle("Simulation") yline(0) ylabel(-0.1(0.05)0.2)
			
		
	restore 
	
end