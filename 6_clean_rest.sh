SUBJID=$1
#fix=/home/dlpfc/Code/FIX/fix1.06/fix

trained_features_1st_cleaning=$inputDir/subjects_1st_cleaning.RData
#trained_features_2nd_cleaning=training_subjects_2nd_cleaning.RData

#create features for first cleaning classification
sh $inputDir/1.sh $SUBJID

# run FIX
# change the threshold
threshold=50
$fix -c $SUBJID $trained_features_1st_cleaning $threshold

clfs=$(tail ${SUBJID}/1st_cleaning/fix4melview_*_LOO_thr${threshold}.txt -n 1 | tr -d '[]')
fsl_regfilt -i ${SUBJID}/1st_cleaning/filtered_func_data.nii.gz -o ${SUBJID}/1st_cleaning/cleaned_data.nii.gz -d ${SUBJID}/1st_cleaning/filtered_func_data.ica/melodic_mix -f "$clfs"

#sh 4.sh $SUBJID

#threshold=50
#$fix -c $SUBJID trained_features_2nd_cleaning $threshold

#clfs=$(tail ${SUBJID}/2nd_cleaning/fix4melview_*_LOO_thr${threshold}.txt -n 1 | tr -d '[]')
#fsl_regfilt -i ${SUBJID}/2nd_cleaning/filtered_func_data.nii.gz -o ${SUBJID}/1st_cleaning/cleaned_data.nii.gz -d ${SUBJID}/1st_cleaning/filtered_func_data.ica/melodic_mix -f "$clfs"

sh $inputDir/ 5.sh
