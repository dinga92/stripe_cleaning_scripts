import nibabel as nb
import numpy as np
import sys

#img_path = '110553/110553_func.nii.gz'
#img_path = '/home/dlpfc/Code/qa_plots/120475_links/stripe_filtered/120475_denoised_tempfilt.nii.gz'

img_path = sys.argv[1]

img = nb.load(img_path)

mean_img = np.mean(img.get_data(),3)
std_img = np.std(img.get_data(), 3)
tsnr_img = mean_img/std_img

output_path = img_path.split('.nii.gz')[0] + '_tsnr.nii.gz'

nii_img = nb.Nifti1Image(tsnr_img, img.get_affine())
nb.save(nii_img, output_path)
