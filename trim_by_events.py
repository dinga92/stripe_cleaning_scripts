"""
takes arguments:
    1st: path to nifti 4D file to be trimmed
    2nd: TR in seconds
    3rd+ paths to event files

Output:
    trimmed 4d nifti file with original file name + trimmed.nii.gz
"""
import nibabel as nb
import sys

nifti_4d_file = sys.argv[1]
TR = float(sys.argv[2])
events = sys.argv[3:]
add_sec = 10


def get_last_tr(events, TR, add_sec):
    last_events = [open(event).readlines()[-1] for event in events]
    onsets = [e.split()[0] for e in last_events]
    last_event = last_events[onsets.index(max(onsets))]
    onset, duration, _ = [float(e) for e in last_event.split()]
    event_end = onset + duration
    cut_after_sec = event_end + add_sec
    last_tr = int(cut_after_sec / TR)
    return last_tr

def trim_data(nifti_4d_file, last_tr):
    nii_img = nb.load(nifti_4d_file)
    data = nii_img.get_data()
    trimmed_data = data[:, :, :, :last_tr]
    trimmed_image = nb.Nifti1Image(trimmed_data, nii_img.get_affine(), header=nii_img.header)
    return trimmed_image


last_tr = get_last_tr(events, TR, add_sec)
trimmed_data = trim_data(nifti_4d_file, last_tr)

output_path = nifti_4d_file.split('.nii.gz')[0] + '_trimmed.nii.gz'
nb.save(trimmed_data, output_path)
