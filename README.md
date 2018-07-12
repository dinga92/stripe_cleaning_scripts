# stripe_cleaning_scripts
Pipeline + miscellaneous scripts to use preprocess data with fsl FIX

## Documentation work in progress

1. Run melodic on raw data
2. Classify components by hand
3. Optional: use FIX to classify components automatically
4. Run rest of the preprocessing 

## Plotting of independent components
ica_stripes_plotting.py is a script meant to make classification of ICA components containing stripes easier. For each sagittal slice, it tries to guess if it contains a stripe and then plots 4 slices that score the highest. It is quite good at capturing stripe artifacts, especially big ones (unlike FIX). It can be used to classify components by hand or to double check classification performed by FIX. 

### Plotting script output
<img src="plotting_test_subject/123456/1st_cleaning/ica_plots/123456_True_IC_3.png" width="400"><img src="plotting_test_subject/123456/1st_cleaning/ica_plots/123456_True_IC_4.png" width="400">
