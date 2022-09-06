# Test-Score-Sensitivity

subsetscore is a user-written command written in Stata 16.

It allows the user to calculate a standardized score from a list of items, and compare that score to the same standardized scores but calculated from random subsets of the full list of items. The objective is to understand how sensitive the score is to the number and nature of items composing it. The command uses the egen functions sum() and std() to calculate the scores. It can be used for any scoring items for which it makes sense to calculate a normalized mean.

There are two possible syntaxes depending on what is selected in the output() option. They are as follows:

`**subsetscore** *stubname*, selected(n) iterations(i) output(out)`

*or*

`**subsetscore** *stubname*, minselected(n) maxselected() iterations(i) output(out)`

*stubname* is the name of the items comprising the score. In the current version of the program, all items must share the same name, with a numerical suffix, much like in a *reshape* command. The numbers at the end of the stubname do not have to follow each other.

*iterations* is the number of times you want to randomly draw a subset of items to calculate a new score. The more iterations, the more informative the outputs will be, but the longer the program will take to run.

the option *selected* is required if the output is either **diff** or **corr**. It determines how many items you want to subset out of your full list of items. The default is 5. For example, if you enter 100 iterations of 5 selected items, the program will randomly select 5 items among your list and calculate a score 100 times.

if you choose output **allcorr**, you will not enter a single number of items to be subsetted, but a minimum and a maximum number of items to be subsetted. The program will run all the simulations in between. For example, if you select 100 iterations of mininum 1 and maximum 7 selected items, the program will calculate 100 scores with 1 selected item, then 100 scores with 2 selected items, then 100 scores with 3 selected items, and so on until 7 selected items.

*output* determines what the program renders. **diff** generates a distribution of the population differences between the full score and each subsetted scores. If you are working with a large population, that difference may be pretty small. **corr** generates a distribution of the correlation between the full score and each subsetted score in your population. **allcorr** calculates the correlation between the full score and each subsetted score in your population, and displays the coefficients as a function of the number of items selected. This can help you determine what is the marginal benefit to adding one more item to your test, for example, if you are planning for data collection.
