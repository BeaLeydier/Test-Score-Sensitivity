
**** Program that OUTPUTS all correlations as a function of the number of items selected

program define selectitems_allcorr

 		syntax namelist(max=1 id="stubname" local), MINselected(integer) MAXselected(integer) ITERations(integer) 

		//TODO: error if max<min; check that max << number of items
		
	preserve 																	// Preserve so that the original dataset comes back

		*Calculate score with all items
		egen sum_total = rowtotal(`namelist'*)
		egen std_total = std(sum_total)
		
		forvalues i = `minselected' / `maxselected' {
			selectitems_data `namelist', selected(`i') iterations(`iterations')			
		}
		
		* Compare all scores with selected items to unique score with all items
		cpcorr std_*items_* \ std_total
		
		* Save matrix of coefficients into a dataset
		svmat2 r(C), names(eqcol) rnames(nitems)										// Make the correlation coefficients into the dataset and use their equation name (ie a _ will be added at the beginning of the coefficient) AND include row names
		keep _*	nitems																	// Only keep these variables
		duplicates drop																	// Delete all the empty obs (all duplicates, fully missing) : now the number of n is the number of correlation coefficients
		drop if _std_tot==.																// Delete an empty obs
		gen n_items = substr(nitems, 5, strpos(nitems, "items") - 5)					// Extract the number of items from the nitems var 
		destring(n_items), replace
		drop nitems																		// Drop the nitems var 
		bys n_items: egen meancorr=mean(_std_tot)										// Obtain the mean correlation for these number of items
		drop _std_tot																	// Collapse the dataset at the number of items level
		duplicates drop
		
		* Display relationship
		twoway (line meancorr n_items, sort), title("Mean Correlation Between Subsetted Score and Full Score") subtitle("As a Function of the Number of Items in the Subsetted Score") ytitle("Mean Correlation (across `iterations' iterations)") xtitle("Number of Items in the Subsetted Score")
		
	restore	
		
end		