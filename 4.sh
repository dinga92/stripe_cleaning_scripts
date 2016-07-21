# this script will take cleaned data from the first cleaning, motion correct them, run melodic and create features for FIX
inputDir=/home/data/lschmaal/Richard/stripe_cleaning/Output
SUBJID=$1
TR=$(grep $SUBJID ${inputDir}/TRs.txt | awk 'NF>1{print $NF}')
FSLBIN=$FSLDIR/bin
#fix=/home/dlpfc/Code/FIX/fix1.06/fix

cd $SUBJID
mkdir 2nd_cleaning

echo copy_data
cp 1st_cleaning/cleaned_data.nii.gz 2nd_cleaning/cleaned_data.nii.gz 
echo

cd 2nd_cleaning

echo get_example 
# Get example_func - i.e. middle volume
# infile: cleaned_data.nii.gz
# outfile: example_func
all_vol=`${FSLBIN}/fslinfo cleaned_data.nii.gz | grep dim4 | head -n 1 | awk '{print $2}'`
all_vol=${all_vol}
middle_vol=`echo $all_vol / 2 | bc`
${FSLBIN}/fslroi cleaned_data.nii.gz example_func ${middle_vol} 1
echo


echo motioncorrection
# motion correcitonw as already run in the first step, however we used it only to create motion parameters for fix, we did not actually used realigned data, therefore we will run motion correction again and realign the data now. 

# infile: cleaned_data.nii.gz
# outfile: prefiltered_func_data_mcf
${FSLBIN}/mcflirt -in cleaned_data.nii.gz -out prefiltered_func_data_mcf -mats -plots -reffile example_func -rmsrel -rmsabs -stats
mkdir mc
mv prefiltered_func_data_mcf* mc/.
mv mc/prefiltered_func_data_mcf.nii.gz filtered_func_data.nii.gz
echo


echo melodic on raw data
# Do Single Subject ICA (melodic)
# Classify stripe components in ${SUBJID}_clf.txt
# infile: ${SUBJID}_func.nii.gz
# outfile: ${SUBJID}_func.ica
melodic_in=filtered_func_data.nii.gz
if [ ! -f $melodic_in ]; then
    echo "input file doesn't exist. Exit."
    exit
fi

${FSLBIN}/melodic --in=$melodic_in --outdir=filtered_func_data.ica --nobet --mmthresh=0.5 --tr=${TR} --Oall

echo create_links
#create links to additional files required for fix that were allready created by 1.sh
ln -s ../reg reg
ln ../mask.nii.gz .
ln filtered_func_data.ica/mean.nii.gz mean_func.nii.gz


echo create_fix_features
$fix -f .
