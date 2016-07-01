# this script will do first cleaning of the data

SUBJID=$1
TR=$(grep $SUBJID ./TRs.txt | awk 'NF>1{print $NF}')

cleaning=$2

echo $cleaning
if [ $cleaning = 1 ]; then
   cleaning_folder=1st_cleaning
elif [ $cleaning = 2 ]; then
   cleaning_folder=2nd_cleaning
else
   echo "second argument required to be 1 or 2 (first or second cleaning). Exit"
   exit
fi

###################################################################
#                     OPTIONAL PART                               # 
# UNCOMMENT ONLY IF DIFFERENT THAN DESIRED THRESHOLD IS REQUIRED  #
###################################################################

## first setup path to LOO folder created by 2_training.sh script
## find out which folder in LOO_folder belongs to current subject
## we are looking for a training data that were used to automatically create fix4melview_*_LOO files with classified components and use them to classify components with different threshold
## because FIX is not creating folder structure with thransparent names we have to find the file by grep

#LOO_folder=training_subjects_LOO
#str="FIX Classifying components in Melodic directory: ${SUBJID}"
#files=$(grep -lr $LOO_folder -e "$str")
#file=$(echo $files | awk '{print $1;}')
#file=$(echo $file | tr '/_' ' ' | awk '{print $(NF-2)}')
#training_data=${LOO_folder}/${file}/*_LOO.RData

#threshold=70

##path to fix command
#fix=/home/dlpfc/Code/FIX/fix1.06/fix

# create file with classified components with a custom threshold
#$fix -c $cleaning_folder $training_data $threshold

#################################################################
#               END OF THE OPTIONAL PART                        #
################################################################# 

cleaning_folder=${SUBJID}/1st_cleaning
# read classifications from automatically created LOO file. 
# Change path to a file with a different threshold if desired
# If there is a need for a different threshold as was automatically created, uncomment and modify the optional part which will create classification file with differnet threshold 
 
# read noise components numbers
clfs=$(tail ${cleaning_folder}/fix4melview_*_LOO_thr50.txt -n 1 | tr -d '[]')

# check if at least some components were classified as noise, if not just copy the uncleaned file, if yes clean the components
if [ "${clfs}" = '' ]; then 
  echo 'Warning: no components classified as noise'
  cp ${cleaning_folder}/filtered_func_data.nii.gz ${cleaning_folder}/cleaned_data.nii.gz
else 
  fsl_regfilt -i ${cleaning_folder}/filtered_func_data.nii.gz -o ${cleaning_folder}/cleaned_data.nii.gz -d ${cleaning_folder}/filtered_func_data.ica/melodic_mix -f "$clfs"
fi








