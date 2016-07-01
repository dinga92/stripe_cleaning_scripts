# this script will run on selected training dataset and train fix to classify noise components
# it will also run leave-one-out crossvalidation on a training dataset (LOO)
# it needs files created by 1.sh script and a text file with numbers of noise components 

#FIX path
fix=/home/dlpfc/Code/FIX/fix1.06/fix

# read text file with subjects numbers one per line
subjects_file=$1
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

# get folder name where the data are stored in form SUBJID/1st_cleaning
subj_dirs=$(sed -e "s/$/\/${cleaning_folder}/" ${subjects_file})
# otput folder name = name of the given subjects file, without .txt suffix
output_folder=$(basename $subjects_file .txt)_${cleaning_folder}

# run training phase of fix + classify components in LOO fashion
$fix -t $output_folder -l $subj_dirs

