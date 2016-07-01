# this script will run rest of the preprocessing pipeline and first level FEAT after the data were cleaned

SUBJID=$1
TR=$(grep $SUBJID ./TRs.txt | awk 'NF>1{print $NF}')

FSLBIN=$FSLDIR/bin
python=python
ICA_AROMA=/home/dlpfc/Code/ICA-AROMA-master/ICA_AROMA.py

echo $SUBJID
echo $TR

cd $SUBJID

echo copy_clean_data
#change this path to 1st cleaning if only one pass of cleaning was performed
cp 2nd_cleaning/cleaned_data.nii.gz .
echo

echo apply_mask
${FSLBIN}/fslmaths cleaned_data.nii.gz -mul mask.nii.gz ${SUBJID}_func_ss.nii.gz
echo


echo grandmeanscaling 
# Do Grand Mean Scaling
# infile: ${SUBJID}_func_ss.nii.gz
# outfile: ${SUBJID}_func_gm.nii.gz
${FSLBIN}/fslmaths ${SUBJID}_func_ss.nii.gz -ing 10000 ${SUBJID}_func_gm.nii.gz -odt float
echo


echo get_quickmask 
# Make quick mask
# infile: ${SUBJID}_func_gm.nii.gz
# outfile: ${SUBJID}_func_gm_mask.nii.gz
${FSLBIN}/fslmaths ${SUBJID}_func_gm.nii.gz -abs -Tmin -bin ${SUBJID}_func_gm_mask.nii.gz
echo


echo spatialsmoothing6 
# Do Spatial Smoothing with FWHM = 6
# infile: ${SUBJID}_func_gm.nii.gz
# outfile: ${SUBJID}_func_sm.nii.gz
${FSLBIN}/fslmaths ${SUBJID}_func_gm.nii.gz -kernel gauss 2.5479870902 -fmean -mas ${SUBJID}_func_gm_mask.nii.gz ${SUBJID}_func_sm.nii.gz
echo


echo ica_aroma+melodic
# Do ICA_AROMA
# melodic is part of ica_aroma 
# infile: ${SUBJID}_func_sm.nii.gz
# outdir: ${SUBJID}_func.ica_aroma
#ICA_aroma needs full path for some reason, assuming ${HOME} == working directory
#/home/common/applications/Python/Python-2.7.8/python /home/data/lschmaal/NESDA_data/ICA-AROMA-master/ICA_AROMA.py -i ${HOME}/${SUBJID}_func_sm.nii.gz -o ${HOME}/${SUBJID}_func.ica_aroma -tr ${TR} -a ${HOME}/${SUBJID}_reg/${SUBJID}_fMRI_example_func_ns2highres.mat -w ${HOME}/${SUBJID}_T1_nonlinear_transf.nii.gz -mc ${HOME}/${SUBJID}_mc/${SUBJID}_func_mc.par  
$python $ICA_AROMA -i $(pwd)/${SUBJID}_func_sm.nii.gz -o $(pwd)/${SUBJID}_func.ica_aroma -tr ${TR} -a /media/dlpfc/Elements/ICA_smoothed/${SUBJID}/${SUBJID}_reg/${SUBJID}_fMRI_example_func_ns2highres.mat -w /media/dlpfc/Elements/ICA_smoothed/${SUBJID}/${SUBJID}_T1_nonlinear_transf.nii.gz -mc ${source_folder}/mc/prefiltered_func_data_mcf.par
echo


echo highpassfilter 
# Do Temporal Filtering
# infile: ${SUBJID}_func.ica_aroma/denoised_func_data_nonaggr_res.nii.gz
# outfile: ${SUBJID}_denoised_tempfilt
${FSLBIN}/fslmaths ${SUBJID}_func.ica_aroma/denoised_func_data_nonaggr.nii.gz -Tmean ${SUBJID}_func.ica_aroma/denoised_func_data_nonaggr_mean.nii.gz
${FSLBIN}/fslmaths ${SUBJID}_func.ica_aroma/denoised_func_data_nonaggr.nii.gz -bptf 19.46450971062762 -1 -add ${SUBJID}_func.ica_aroma/denoised_func_data_nonaggr_mean.nii.gz ${SUBJID}_denoised_tempfilt 
echo



EVDIR=/home/dlpfc/Code/imaging_geest/processing_scripts/Pauls/ToL_pipelines/0/designs_tol/${SUBJID}

echo 'FEAT: set variables and make a config file'
# infile: template .fsf file
# outfile: ${SUBJID}_FEAT.fsf

# First level design
# Set directories
TEMPLATEDIR=/home/dlpfc/Code/imaging_geest/processing_scripts/Pauls/ToL_pipelines/0

# Set some variables
OUTPUTDIR=${HOME}/fixed_stripes.feat
DATA=${HOME}/${SUBJID}_denoised_tempfilt.nii.gz 
vol=`${FSLBIN}/fslnvols ${SUBJID}_denoised_tempfilt.nii.gz`
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
-e 's@#DATA#@'$DATA'@g' <$i> $(pwd)/${SUBJID}_FEAT.fsf
done

#Run feat analysis
echo 'FEAT denoised soft: run the analysis'
${FSLBIN}/feat $(pwd)/${SUBJID}_FEAT.fsf 


echo register_stats
# z*.nii.gz t*.nii.gz c*.nii.gz f*.nii.gz
cd ${OUTPUTDIR}
mkdir reg_standard
mkdir reg_standard/stats

for f in stats/z*.nii.gz stats/t*.nii.gz stats/c*.nii.gz stats/f*.nii.gz stats/var*.nii.gz; do   
  ${FSLBIN}/applywarp --ref=${FSLDIR}/data/standard/MNI152_T1_2mm --in=${f} --warp=../${SUBJID}_T1_nonlinear_transf.nii.gz --premat=../reg/fMRI_example_func_ns.mat --out=../reg_standard/${f}  ; 
done


