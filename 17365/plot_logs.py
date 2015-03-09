#!/bin/env python

import os
import sys

import numpy as np

from subprocess import Popen, PIPE
 


try:
    #
    # parse command line arguments
    #
    log_files  = [ str(f) for f in sys.argv[1:] ]
    if len (log_files) == 0:
        raise ValueError ( )

except (IndexError, ValueError):
    #
    # usage message
    #
    sys.stderr.write ("Usage: %s [files ...]\n" % sys.argv[0])
    sys.stderr.write ("Aggregates and plots the test results from different systems.-\n")
    sys.stderr.write (" [files ...] a space-separated list of files to plot\n")
    sys.exit (1)

#
# tested MPI message sizes
# 
msg_sizes = [1]
for i in range (1, 23):
    msg_sizes.append (msg_sizes[-1] * 2)

#
# analyze each of the log files
#
res = list ( )
settings = list ( )
for f in log_files:
    #
    # the settings under which the tests were run
    #
    settings.append (Popen ("grep MV2 %s | sed -e 's/^#//g'" % f,
                            shell=True,
                            stdout=PIPE).stdout.read ( ))
    #
    # load the test results
    #
    res.append (np.loadtxt ("%s" % f))

#
# print out the results
#
print ("#")
print ("# G2G bandwidth statistics")
print ("#")
for i in range (len (res)):
    print ("#")
    print ("# Settings %d" % i)
    print ("#")
    for s in settings[i].decode ('utf-8').split ('\n'):
        print ("# %s" % s)
    print ("# msg\tMB/s")
    for r in res[i]:
        print ("%d\t%.3f" % (r[0], r[1]))

try:
    #
    # plot the results
    #
    import matplotlib.pyplot as plt

    bar_width = 3.5
    ax = plt.subplot (111)
    bars = []
    colors = ('red', 
              'green', 
              'yellow', 
              'blue', 
              'magenta', 
              'black', 
              'cyan',
              'gray')
    locations = np.arange (len (msg_sizes))
    locations *= 2*len (msg_sizes)
    for i in range (len (res)):
        bars.append (ax.bar (locations + (i*bar_width),
                             res[i][:,1],
                             color=colors[i],
                             width=bar_width))

    ax.grid (True)
    ax.legend ( [ b[0] for b in bars ],
                ['Settings %d' % i for i in range (len (settings)) ],
                loc='upper left')
    #ax.set_xlim ([0, len (maximum)])
    ax.set_xticks (locations + 4*bar_width)
    ax.set_xticklabels ( (msg_sizes) )
    plt.ylabel ("Bandwidth [MB/s]")
    plt.xlabel ("Message size [Bytes]")

    img_plot = '/tmp/%s.eps' % str (int (np.random.rand ( ) * 1000000))
    print ("# Saving plot to %s ..." % img_plot)
    plt.savefig (img_plot,
                 format='eps', 
                 dpi=600)
    plt.show ( )

except ImportError:
    sys.stderr.write ("WARNING: not displaying plot. Matplotlib not available.\n")
    sys.exit (0)

