# this script will do first part of preprocessing
# 1. run melodic on raw data (no preprocessing)
# 2. run motion correction and registration in order to create required data for FIX (motion parameters and warp files)
# however we are still wroking on non motion corrected data in the subject space
# 3. create FIX folder and FIX features to classify components 
# This script run correctly if there is a fix folder in subjects directory with features.csv file

#setup paths
#FSLBIN=$FSLDIR/bin
#fix=/home/dlpfc/Code/FIX/fix1.06/fix


# setup variables
SUBJID=$1

TR=$(grep $SUBJID $inputDir/TRs.txt | awk 'NF>1{print $NF}')
#func_data=$inputDir/source_data/${SUBJID}/${SUBJID}_func.nii.gz
#t1_data=$inputDir/source_data/${SUBJID}/${SUBJID}_T1.nii.gz
func_data=$inputDir/links/${SUBJID}_Functional.img
t1_data=$inputDir/links/${SUBJID}_T1.img

echo $SUBJID $TR

mkdir $SUBJID
cd $SUBJID

#coment this out if the data are allready in nifty format
echo convert_to_nii
# convert epi and T1 to nii files
mri_convert -i $func_data -it img -ot nii -o func.nii.gz
mri_convert -i $t1_data -it img -ot nii -o T1.nii.gz  
echo

# coment this out if the original data are not in the nifty format
#echo copydata
#cp $func_data .
#cp $func_data ./func.nii.gz
#cp $t1_data ./T1.nii.gz
#echo

echo create_tsnr
python $inputDir/make_tsnr.py func.nii.gz
echo

echo melodic on raw data
# Do Single Subject ICA (melodic)
# infile: func_data.nii.gz
# outfile: filtered_func_data.ica

# don't run melodic if file doesn't exist
melodic_in=func.nii.gz
if [ ! -f $melodic_in ]; then
    echo "input file doesn't exist. Exit."
    exit
fi

melodic --in=$melodic_in --outdir=filtered_func_data.ica --nobet --mmthresh=0.5 --tr=${TR} --Oall

# copy file instead of running melodic
#cp $inputDir/source_data/${SUBJID}_script1.tar.bz2 .
#tar -xjf ${SUBJID}_script1.tar.bz2 && rm ${SUBJID}_script1.tar.bz2
#mv ${SUBJID}_func_raw.ica filtered_func_data.ica

echo get_example 
# Get example_func - i.e. middle volume
# infile: func
# outfile: example_func
all_vol=`fslinfo func.nii.gz  | grep dim4 | head -n 1 | awk '{print $2}'`
all_vol=${all_vol}
middle_vol=`echo $all_vol / 2 | bc`
fslroi func example_func ${middle_vol} 1
echo


echo motioncorrection_for_fix
# Do motion correction to get motion parameter file for FIX mc/prefiltered_func_data_mcf.par
# other files from this steps will not be used
# infile: func
# outfile: mc/prefiltered_func_data_mcf.par
mcflirt -in func -out prefiltered_func_data_mcf -mats -plots -reffile example_func -rmsrel -rmsabs -stats
mkdir mc
mv prefiltered_func_data_mcf* mc/.
echo


echo skullstrip_fsl 
# Masking Skull from Image, a.k.a. skullstripping
# infile: mc/prefiltered_func_data_mcf.nii.gz
# outfile: func_ss.nii.gz

# 1. Create mean image
# infile: mc/prefiltered_func_data_mcf.nii.gz
# outfile: mean_func.nii.gz
fslmaths mc/prefiltered_func_data_mcf.nii.gz -Tmean mean_func.nii.gz

# 2. Bet mean image
# infile: mean_func.nii.gz
# outfile:  mean_func_brain
bet mean_func.nii.gz mean_func_brain -f 0.5 -n -m -R
# 3. Apply mask
# infile:mc/prefiltered_func_data_mcf.nii.gz
# outfile: func_ss.nii.gz
fslmaths mc/prefiltered_func_data_mcf.nii.gz -mul mean_func_brain.nii.gz func_ss.nii.gz

mv mean_func_brain_mask.nii.gz mask.nii.gz
echo


echo bet_examplefunc 
# Skullstrip image
# infile: example_func
# outfile: example_func_ns
bet example_func example_func_ns -f 0.5 -n -m -R -o
echo


echo bet_T1
# Skullstrip T1
# infile: T1.nii.gz
# outfile: highres
bet T1.nii.gz highres  -f 0.5 -g 0 -m
echo


echo register_T1_to_MNI
# warp T1 to MNI
# infile: highres
# outfile: T1_to_MNI_2mm.nii.gz

# 1. linear preregistration
# infile: highres.nii.gz
# outfile: T1_affine_transf.mat
flirt -ref ${FSLDIR}/data/standard/MNI152_T1_2mm_brain -in highres.nii.gz -omat T1_affine_transf.mat

# 2. nonlinear registration
# infile: T1.nii.gz
# outfile: T1_to_MNI_2mm.nii.gz
fnirt --in=T1.nii.gz --aff=T1_affine_transf.mat --cout=T1_nonlinear_transf --iout=T1_to_MNI_2mm.nii.gz --config=T1_2_MNI152_2mm
echo


echo bbreg 
# Do boundary based registration of functional to T1
# infile: example_func_ns
# outdir: reg
# Avoid weird cluster error
mkdir reg
mv example_func_ns.nii.gz reg/example_func_ns.nii.gz
mv highres.nii.gz reg/highres.nii.gz
mv example_func.nii.gz reg/.
## Execute epi_reg
epi_reg --epi=reg/example_func_ns.nii.gz --t1=T1.nii.gz --t1brain=reg/highres.nii.gz --out=reg/fMRI_example_func_ns2highres

## Calculate inverse transformation matrix
convert_xfm -omat reg/fMRI_example_func_ns.mat -inverse reg/fMRI_example_func_ns2highres.mat
mv reg/fMRI_example_func_ns.mat reg/highres2example_func.mat

echo register mask and mean img
applywarp -i mask.nii.gz -o reg/mask_highres.nii.gz -r reg/fMRI_example_func_ns2highres.nii.gz --premat=reg/fMRI_example_func_ns2highres.mat
applywarp -i mean_func.nii.gz -o reg/mean_func_highres.nii.gz -r reg/fMRI_example_func_ns2highres.nii.gz --premat=reg/fMRI_example_func_ns2highres.mat

applywarp --ref=${FSLDIR}/data/standard/MNI152_T1_2mm --in=mask.nii.gz --warp=T1_nonlinear_transf.nii.gz --premat=reg/fMRI_example_func_ns2highres.mat --out=reg/func_mask_mni.nii.gz
applywarp --ref=${FSLDIR}/data/standard/MNI152_T1_2mm --in=mean_func.nii.gz --warp=T1_nonlinear_transf.nii.gz --premat=reg/fMRI_example_func_ns2highres.mat --out=reg/mean_func_mni.nii.gz

mkdir 1st_cleaning
mv func.nii.gz 1st_cleaning/filtered_func_data.nii.gz
mv filtered_func_data.ica 1st_cleaning/.
mv $(pwd)/mc 1st_cleaning/.
ln $(pwd)/mask.nii.gz 1st_cleaning/.                       
ln -s $(pwd)/mean_func.nii.gz 1st_cleaning/.                   
ln -s $(pwd)/reg 1st_cleaning/.

# remove big unnecesary files
rm 1st_cleaning/mc/prefiltered_func_data_mcf.nii.gz

echo create_qa_plots
python $inputDir/plotting.py . $inputDir/plot_config.txt

echo create fix features
# run fix, create features
$fix -f ./1st_cleaning

