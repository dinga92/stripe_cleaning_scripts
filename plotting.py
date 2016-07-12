from nilearn import plotting
import os
import sys
import nibabel as nb
import numpy as np

opj = os.path.join


#f = open(sys.argv[1])
#folder = '110553'
#plot_config = 'plot_config.txt'

folder = sys.argv[1]
plot_config = sys.argv[2]

f = open(plot_config)

try:
    os.mkdir(opj(folder, 'qa_plots'))
except:
    import shutil
    shutil.rmtree(opj(folder, 'qa_plots'), ignore_errors=True)
    os.mkdir(opj(folder, 'qa_plots'))
    pass

i = 0
for line in f:
    if not line.strip():
        continue
    if line[0] == '#':
        continue


    print 'line: ', line
    #for words
    words = ('add_contours', 'add_edges')
    verbs = [e for e in line.split() if e in words]
    print verbs
    line = line.replace('add_contours', '%%%%%')
    line = line.replace('add_edges', '%%%%%')
    elements = line.split('%%%%%')
    print len(elements)

    path, display_mode, cut_coords = elements[0].split()

    path = opj(folder, path)
    print path, display_mode, cut_coords

    data = nb.load(path).get_data().flatten()
    data = sorted(data[~np.isnan(data)])
    vmax=data[int(len(data)*0.99)]
    print vmax


    display = plotting.plot_anat(path,
                   vmin=0,
                   vmax=vmax,
                   display_mode=display_mode,
                   cut_coords=int(cut_coords))


    print elements
    for element in elements[1:]:
        print
        path = element.split()[0]
        path = opj(folder, path)
        print element, 'path = ', path
        #display.add_edges(path)
        verb = verbs.pop(0)
        print verb
        if verb == 'add_contours':
            display.add_contours(path, levels=[0.1], colors='r')
        elif verb == 'add_edges':
            display.add_edges(path)
        else:
            print 'error'

    display.savefig(opj(folder, 'qa_plots/%s.png' %i))
    i += 1
#
#    display.add_contours(path)
f.close()

num_of_images=len([f for f in os.listdir(opj(folder, 'qa_plots')) if f.endswith('png')])

f = open(opj(folder, 'qa_plots/index.html'), 'w')

print >> f, '<HTML><HEAD><TITLE>QA plots</TITLE></HEAD><BODY>'
for i in range(num_of_images):
    print >> f, '<img BORDER=0 SRC="%s.png"><p>' %(i)
f.close()
