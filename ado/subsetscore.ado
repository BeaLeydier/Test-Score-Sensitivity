/*******************************************************************************

	.ado file that defines subset of scores from longer list items of scores
	and returns one of three things
	
		1. a histogram of the population difference between subsetted scores and full score
		2. a histogram of the correlation between subsetted scores and full score
		3. a function of the correlation between subsetted scores and full score
			against the number of variables in the subsetted score
			
*******************************************************************************/

program define subsetscore 

	syntax namelist(max=1 id="stubname" local), ITERations(integer) OUTput(name) [SELECTed(integer 5) MINselected(integer 1) MAXselected(integer 10)]  


	if "`output'" == "corr" {
		
		selectitems_corr `namelist', selected(`selected') iterations(`iterations')
		
	}
	

	if "`output'" == "allcorr" {
		
		selectitems_allcorr `namelist', minselected(`minselected') maxselected(`maxselected') iterations(`iterations')
		
	}
	
end
