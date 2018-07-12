 #!/usr/bin/env

import nilearn
from nilearn.input_data import NiftiMasker
from nilearn.plotting import plot_glass_brain
import numpy as np
import matplotlib.pyplot as plt
import scipy
from scipy import signal
from skimage.morphology import disk
from skimage.filters.rank import median
import warnings


def load_subj_fmri_data(melodic_oIC_path, mask_path):    
    ica_images_raw = nilearn.image.load_img(melodic_oIC_path)
    ica_images_masker = NiftiMasker(smoothing_fwhm=None, mask_img=mask_path) 
    ica_images_masked = ica_images_masker.fit_transform(ica_images_raw)
    return ica_images_raw, ica_images_masked, ica_images_masker
    
    
def load_subj_ica_classifications(clfs_file_path):
    if not os.path.exists(clfs_file_path):
        clfs = []
        print('No classification file was provided, or path was wrong, all components are treated as unclassified')
        return clfs
        
    with open(clfs_file_path) as f:
        clfs = f.readlines()[-1]        
    for char in ['[', ']', '\n']:
        clfs = clfs.replace(char, '')
    clfs = [int(e) for e in clfs.split(',')]
    return clfs
    
    
def load_subj_ica_data(melodic_timeseries_path, melodic_powerspectra_path):
    melodic_timeseries = np.loadtxt(melodic_timeseries_path)
    melodic_powerspectra = np.loadtxt(melodic_powerspectra_path)
    return melodic_timeseries, melodic_powerspectra

    
def preproc_ic_img(ic_img_1d, ica_images_masker):    
    ic_img_2d = ica_images_masker.inverse_transform(ic_img_1d).get_data()
    ic_img_2d = abs(ic_img_2d)
    ic_img_2d /= np.nanmax(ic_img_2d)
    ic_img_2d[ic_img_2d==0] = 1
    ic_img_2d = 1 - ic_img_2d    
    return ic_img_2d
    
    
def get_max_stripe_size_per_ic(ica_images_masked, ica_images_masker):
    stripe_magnitude_per_ic = []    
    for ic in range(ica_images_masked.shape[0]):    
        ic_img_2d = preproc_ic_img(ica_images_masked[ic], ica_images_masker)               
        stripe_magnitude_per_slice = [(find_biggest_stripe_in_slice(ic_img_2d[i]), i) 
                            for i in range(ic_img_2d.shape[0])]
        stripe_magnitude_per_ic.append((np.min(stripe_magnitude_per_slice), ic))
    return stripe_magnitude_per_ic

    
def find_biggest_stripe_in_slice(slice_2d):    
    nzero = np.sum(slice_2d == 0)
    if nzero > 3000: # skip slices with too few voxels
        return 0            
    dip_sizes, _, _, _, _ = columnwise_signal_dips(slice_2d) 
    return(np.min(dip_sizes))

    
def columnwise_signal_dips(slice_2d):
    median_filtered_picture = preproc_2d_img(slice_2d)
    col_means = img_to_colmeans(median_filtered_picture)
    smoothed_col_means = scipy.ndimage.filters.gaussian_filter(col_means, 1)
    peaks, valleys = get_series_peaks_and_valleys(smoothed_col_means)      
    dip_sizes = get_dip_sizes(peaks, valleys, smoothed_col_means)
    #TODO: make this less confusing
    return dip_sizes, col_means, peaks, valleys, median_filtered_picture
            
    
def preproc_2d_img(img):
    #silence Possible precision loss when converting from float64 to uint8 warning
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        picture = np.rot90(img)
        picture /= np.max(picture)
        # apply median filter to make stripes more vissible
        picture = median(picture, disk(1))
        return picture
    
        
def img_to_colmeans(img):
    #silence divide by 0 warning
    with np.errstate(divide='ignore',invalid='ignore'):
        non_zero = np.mean(img != 0, axis=0)    
        time_series = np.sum(img, axis=0)/non_zero
        #nan due to divide by 0 are converted to 0
        time_series[np.isnan(time_series)] = 0
        time_series /= 100
        return time_series

        
def get_series_peaks_and_valleys(series):
    valleys = signal.argrelmin(series)[0]
    peaks = signal.argrelmax(series)[0]
    return peaks, valleys

    
def get_dip_sizes(peaks, valleys, col_means):
    dip_sizes = []
    for index_min in range(len(valleys)):
        _min = col_means[valleys[index_min]]
        _max = min(col_means[np.max(peaks[index_min])], col_means[np.max(peaks[index_min+1])])
        dip_sizes.append(_min - _max)
    if dip_sizes == []:
        dip_sizes = [0] 
    return dip_sizes

    
def plot_stripes_in_ic(ic_img, melmix_ic_power, melmix_ic_timecourse, nifti_img, ic,):
    fig = plt.figure()
    fig.subplots_adjust(hspace=0.45, wspace=0.1)     
    
    stripe_magnitude_per_slice = sorted([(find_biggest_stripe_in_slice(ic_img[i]), i) 
                        for i in range(ic_img.shape[0])])    
    i = 1
    for stripe_magnitude, slice_index in stripe_magnitude_per_slice[:4]:
        slice_2d = ic_img[slice_index]        
        dip_sizes, col_means, peaks, valleys, median_filtered_picture = columnwise_signal_dips(slice_2d)                
        stripe_mask = get_stripe_mask(col_means, dip_sizes, valleys)*10
        dips = get_dips(dip_sizes, col_means, valleys)
        
        ax = fig.add_subplot(4, 2, i+2)
        ax.get_yaxis().set_visible(False)
        ax.imshow(median_filtered_picture)
        ax.plot(34 - dips, color='white')
        ax.plot(34-stripe_mask, color='red')        
        plt.title('ic:%s slice:%s magnitude:%s' %(
                ic+1, slice_index, abs(np.round(np.min(dip_sizes),2))))        
        i += 1
    
    ax2 = fig.add_subplot(4, 2, 7)
    ax2.plot(melmix_ic_power)
    plt.title('Powerspectrum')
    ax3 = fig.add_subplot(4, 2, 8)
    ax3.plot(melmix_ic_timecourse)
    plt.title('Timecourse')
    
    ax0 = fig.add_subplot(4,1,1)
    plot_glass_brain(nifti_img, title=ic+1, axes=ax0)
    return fig

    
def get_stripe_mask(col_means, dip_sizes, mins):
    dips = get_dips(dip_sizes, col_means, mins)
    dip_pos = np.argmax(dips)
    dip_col_mean = col_means[dip_pos]    
    mask_limit = dip_col_mean + np.max(dips)*0.8
    right_edge = (i for i,v in enumerate(col_means) if v>mask_limit and i > dip_pos).__next__()
    left_edge = (i for i,v in reversed([pair for pair in enumerate(col_means)]) if v>mask_limit and i < dip_pos).__next__()
    stripe_mask = np.array([0]*len(col_means))
    stripe_mask[range(left_edge+1,right_edge)] = 1      
    return stripe_mask

def get_dips(dip_sizes, col_means, mins):
    dips = np.array([0.]*len(col_means))
    dips[mins] = dip_sizes
    return abs(dips)

    
subjid = 123456

import sys
subj_path = sys.argv[1]
if not subj_path.endswith('/'):
    subj_path += '/'    
subjid = subj_path.split('/')[-2]


#subj_path = '/home/dlpfc/Code/rs_prediction/temp/%s/' %subjid
melodic_oIC_path = subj_path + '1st_cleaning/filtered_func_data.ica/melodic_oIC.nii.gz'
mask_path = subj_path + '1st_cleaning/mask.nii.gz' 
classifications_file_path = subj_path + '1st_cleaning/fix4melview_1st_fix_thr50.txt'
melodic_timeseries_path =  subj_path + '1st_cleaning/filtered_func_data.ica/melodic_mix'    
melodic_powerspectra_path = subj_path + '1st_cleaning/filtered_func_data.ica/melodic_FTmix'
outcome_folder = subj_path + '1st_cleaning/ica_plots/'
print('Plotting figures\nsubjid=%s\nsubj_path=%s\noutcome_folder=%s '%(subjid, subj_path, outcome_folder))


import os
if not os.path.exists(outcome_folder):
    os.makedirs(outcome_folder)

ica_images_raw, ica_images_masked, ica_images_masker = load_subj_fmri_data(melodic_oIC_path, mask_path)
classified_components_id = load_subj_ica_classifications(classifications_file_path)
ica_timeseries, ica_powerspectra = load_subj_ica_data(melodic_timeseries_path, melodic_powerspectra_path)
stripe_magnitude_per_ic = get_max_stripe_size_per_ic(ica_images_masked, ica_images_masker)

num_figures = len(stripe_magnitude_per_ic) 
figure_number = 1
for stripe_magnitude, ic in stripe_magnitude_per_ic:        
    ic_image_masked_1d = ica_images_masked[ic]      
    ic_image_masked_2d = preproc_ic_img(ic_image_masked_1d, ica_images_masker)    
    ic_powerspectrum = ica_powerspectra[:,ic]
    ic_timeserie = ica_timeseries[:,ic]
    ic_image_raw = nilearn.image.index_img(ica_images_raw, ic)
    
    #it's ic+1 because python index from 0, but we want from 1
    if ic+1 in classified_components_id:
        classified = True
    else:
        classified = False    
    #TODO: make plotting faster    
    plt.rcParams["figure.figsize"] = [9,10]
    fig = plot_stripes_in_ic(ic_image_masked_2d, 
                             ic_powerspectrum, 
                             ic_timeserie,                             
                             ic_image_raw,
                             ic)         
    file_name = '%s_%s_IC_%s.png' %(subjid, classified, ic+1)
    fig.savefig(outcome_folder + file_name,  
                bbox_inches='tight')
    plt.close(fig)
    plt.clf()
    
    print(file_name, figure_number , '/', num_figures)
    figure_number += 1
        
print('%s DONE!!!' %subjid)


#return('a')
    
#def ploting_worker(subjid):

#import multiprocessing as mp
#
#if __name__=='__main__':
#    p = mp.Pool(6, maxtasksperchild=1)
#    res = p.imap_unordered(ploting_worker, []) 
#    p.close()
#    p.join()
    







