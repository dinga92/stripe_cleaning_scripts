# this script will run rest of the preprocessing pipeline and first level FEAT after the data were cleaned

SUBJID=$1
TR=$(grep $SUBJID $inputDir/TRs.txt | awk 'NF>1{print $NF}')

#FSLBIN=$FSLDIR/bin
#python=python
#ICA_AROMA=/home/dlpfc/Code/ICA-AROMA-master/ICA_AROMA.py

echo $SUBJID
echo $TR

cd $SUBJID

echo copy_clean_data
#change this path to 1st cleaning if only one pass of cleaning was performed
#cp 2nd_cleaning/cleaned_data.nii.gz .

# run motion correction only if the second cleaning pass was not done before
echo motioncorrection
# motion correcitonw as already run in the first step, however we used it only to create motion parameters for fix, we did not actually used realigned data, therefore we will run motion correction again and realign the data now. 

# infile: cleaned_data.nii.gz
# outfile: prefiltered_func_data_mcf
mcflirt -in 1st_cleaning/cleaned_data.nii.gz -out prefiltered_func_data_mcf -mats -plots -reffile reg/example_func -rmsrel -rmsabs -stats
mkdir mc
mv prefiltered_func_data_mcf* mc/.
mv mc/prefiltered_func_data_mcf.nii.gz filtered_func_data.nii.gz
mv filtered_func_data.nii.gz cleaned_data.nii.gz
echo


echo apply_mask
fslmaths cleaned_data.nii.gz -mul mask.nii.gz func_ss.nii.gz
echo


echo grandmeanscaling 
# Do Grand Mean Scaling
# infile: func_ss.nii.gz
# outfile: func_gm.nii.gz
fslmaths func_ss.nii.gz -ing 10000 func_gm.nii.gz -odt float
echo


echo get_quickmask 
# Make quick mask
# infile: func_gm.nii.gz
# outfile: func_gm_mask.nii.gz
fslmaths func_gm.nii.gz -abs -Tmin -bin func_gm_mask.nii.gz
echo


echo spatialsmoothing6 
# Do Spatial Smoothing with FWHM = 6
# infile: func_gm.nii.gz
# outfile: func_sm.nii.gz
fslmaths func_gm.nii.gz -kernel gauss 2.5479870902 -fmean -mas func_gm_mask.nii.gz func_sm.nii.gz
echo


echo ica_aroma+melodic
# Do ICA_AROMA
# melodic is part of ica_aroma 
# infile: func_sm.nii.gz
# outdir: func.ica_aroma
#ICA_aroma needs full path for some reason, assuming ${HOME} == working directory
#/home/common/applications/Python/Python-2.7.8/python /home/data/lschmaal/NESDA_data/ICA-AROMA-master/ICA_AROMA.py -i ${HOME}/func_sm.nii.gz -o ${HOME}/func.ica_aroma -tr ${TR} -a ${HOME}/reg/fMRI_example_func_ns2highres.mat -w ${HOME}/T1_nonlinear_transf.nii.gz -mc ${HOME}/mc/func_mc.par  
$python $ICA_AROMA -i $(pwd)/func_sm.nii.gz -o $(pwd)/func.ica_aroma -tr ${TR} -a /media/dlpfc/Elements/ICA_smoothed/${SUBJID}/reg/fMRI_example_func_ns2highres.mat -w /media/dlpfc/Elements/ICA_smoothed/${SUBJID}/T1_nonlinear_transf.nii.gz -mc ${source_folder}/mc/prefiltered_func_data_mcf.par
echo


echo highpassfilter 
# Do Temporal Filtering
# infile: func.ica_aroma/denoised_func_data_nonaggr_res.nii.gz
# outfile: denoised_tempfilt
fslmaths func.ica_aroma/denoised_func_data_nonaggr.nii.gz -Tmean func.ica_aroma/denoised_func_data_nonaggr_mean.nii.gz
fslmaths func.ica_aroma/denoised_func_data_nonaggr.nii.gz -bptf 19.46450971062762 -1 -add func.ica_aroma/denoised_func_data_nonaggr_mean.nii.gz denoised_tempfilt 
echo



EVDIR=/home/dlpfc/Code/imaging_geest/processing_scripts/Pauls/ToL_pipelines/0/designs_tol/${SUBJID}

echo 'FEAT: set variables and make a config file'
# infile: template .fsf file
# outfile: FEAT.fsf

# First level design
# Set directories
TEMPLATEDIR=/home/dlpfc/Code/imaging_geest/processing_scripts/Pauls/ToL_pipelines/0

# Set some variables
OUTPUTDIR=${HOME}/fixed_stripes.feat
DATA=${HOME}/denoised_tempfilt.nii.gz 
vol=`fslnvols denoised_tempfilt.nii.gz`
VOLUMES=${vol}

EV1=${EVDIR}/step1.txt
EV2=${EVDIR}/step2.txt
EV3=${EVDIR}/step3.txt
EV4=${EVDIR}/step4.txt
EV5=${EVDIR}/step5.txt
EV6=${EVDIR}/baseline1.txt
EV7=${EVDIR}/baseline2.txt
EV8=${EVDIR}/false.txt

for i in ${TEMPLATEDIR}/design.fsf; do
sed -e 's@#OUTPUTDIR#@'$OUTPUTDIR'@g' \
-e 's@#EV1#@'$EV1'@g' \
-e 's@#EV2#@'$EV2'@g' \
-e 's@#EV3#@'$EV3'@g' \
-e 's@#EV4#@'$EV4'@g' \
-e 's@#EV5#@'$EV5'@g' \
-e 's@#EV6#@'$EV6'@g' \
-e 's@#EV7#@'$EV7'@g' \
-e 's@#EV8#@'$EV8'@g' \
-e 's@#VOLUMES#@'$VOLUMES'@g' \
-e 's@#TR#@'$TR'@g' \
-e 's@#DATA#@'$DATA'@g' <$i> $(pwd)/FEAT.fsf
done

#Run feat analysis
echo 'FEAT denoised soft: run the analysis'
feat $(pwd)/FEAT.fsf 


echo register_stats
# z*.nii.gz t*.nii.gz c*.nii.gz f*.nii.gz
cd ${OUTPUTDIR}
mkdir reg_standard
mkdir reg_standard/stats

for f in stats/z*.nii.gz stats/t*.nii.gz stats/c*.nii.gz stats/f*.nii.gz stats/var*.nii.gz; do   
  applywarp --ref=${FSLDIR}/data/standard/MNI152_T1_2mm --in=${f} --warp=../T1_nonlinear_transf.nii.gz --premat=../reg/fMRI_example_func_ns.mat --out=../reg_standard/${f}  ; 
done


