#!/usr/bin/env python
# -*- coding: us-ascii -*-
#----------------------------------------------------------------------------

#> @file
## Check yaml output for tests
## @author
##    Copyright (C) 2012-2013 BigDFT group
##    This file is distributed under the terms of the
##    GNU General Public License, see ~/COPYING file
##    or http://www.gnu.org/copyleft/gpl.txt .
##    For the list of contributors, see ~/AUTHORS


import math
import sys
import os
import copy
import optparse

# path of the script
path = os.path.dirname(sys.argv[0])
#yaml_folder = '/local/gigi/binaries/ifort-OMP-OCL-CUDA-gC/PyYAML-3.10/lib'
# if yaml_folder not in sys.path:
#  sys.path.insert(0,'/local/gigi/binaries/ifort-OMP-OCL-CUDA-gC/PyYAML-3.10/lib')

# Check the version of python
version = map(int, sys.version_info[0:3])
if version <= [2, 5, 0]:
    print 70 * "-", 'Fatal error, Compatibility Problem!'
    sys.stdout.write("Detected version %d.%d.%d\n" % tuple(version))
    sys.stdout.write(
        "Due to PyYaml, minimal required version is python 2.5.0\n")
    print 'Solution:', 30 * "-", 'Try to use a newer version of Python! (Python 2.5.0 : Early 2007)'
    sys.exit(1)


import yaml
#from yaml_hl import *

# start_fail = "<fail>" #"\033[0;31m"
#start_fail_esc = "\033[0;31m "
#start_success = "\033[0;32m "
#start_pass = "<pass>"
# end = "</end>" #"\033[m"
#end_esc = "\033[m "


def ignore_key(key):
    "Return True if the key has to be ignored."
    ret = key in keys_to_ignore
    if (not(ret)):
        for p in patterns_to_ignore:
            if str(key).find(p) > -1:
                ret = True
                exit
    return ret


def compare(data, ref, tols=None, always_fails=False):
    """Generic document comparison routine
       descend recursively in the dictionary until a scalar is found
       a tolerance value might be passed"""
    #  if tols is not None:
    #  if (discrepancy > 1.85e-9):
    #  print 'test',data,ref,tols,discrepancy
    if data is None:
        return (True, None)
    elif isinstance(ref,dict):
        # for a floating point the reference is set for all the lower levels
        if isinstance(tols,float):
            neweps = tols
            tols = {}
            for key in ref:
                if key in def_tols:
                    tols[key] = def_tols[key]
                else:
                    tols[key] = neweps
            # print neweps,tols,def_tols
        ret = compare_map(data, ref, tols, always_fails)
    elif isinstance(ref,list):
        if isinstance(tols,float):
            neweps = tols
            tols = []
            tols.append(neweps)
        ret = compare_seq(data, ref, tols, always_fails)
    else:
        ret = compare_scl(data, ref, tols, always_fails)
    return ret


def compare_seq(seq, ref, tols, always_fails=False):
    "Sequence comparison routine"
    global failed_checks
    if tols is not None:
        if len(ref) == len(seq):
            for i in range(len(ref)):
                # print 'here',ref[i],seq[i],tols[0]
                (failed, newtols) = compare(seq[i], ref[i], tols[0], always_fails)
                # Add to the tolerance dictionary a failed result
                if failed:
                    # and type(tols) == type({}):
                    if isinstance(newtols,dict):
                        # print
                        # seq,ref,'tols',tols,'newtols',newtols,type(tols)
                        if not isinstance(tols[0],float):
                            tols[0].update(newtols)
                    elif isinstance(newtols,list):
                        tols[0] = newtols
                    else:
                        tols[0] = max(newtols, tols[0])
        else:
            print 'compare sequence: problem with length 1'
            failed_checks += 1
            if len(tols) == 0:
                tols.append("NOT SAME LENGTH")
            else:
                tols[0] = "NOT SAME LENGTH"
    else:
        tols = []
        if len(ref) == len(seq):
            for i in range(len(ref)):
                if len(tols) == 0:
                    (failed, newtols) = compare(
                        seq[i], ref[i], always_fails=always_fails)
                    #  add to the tolerance dictionary a failed result
                    if failed:
                        tols.append(newtols)
                else:
                    (failed, newtols) = compare(
                        seq[i], ref[i], tols[0], always_fails=always_fails)
                    if failed:
                        tols[0] = newtols
        else:
            print 'compare sequence: problem with length 2'
            failed_checks += 1
            if len(tols) == 0:
                tols.append("NOT SAME LENGTH")
            else:
                tols[0] = "NOT SAME LENGTH"
    return (len(tols) > 0, tols)


def compare_map(map, ref, tols, always_fails=False):
    "Comparison of maps"
    global docmiss, docmiss_it
    if tols is None:
        tols = {}
    for key in ref:
        if not(ignore_key(key)):
            if not(key in map):
                docmiss += 1
                docmiss_it.append(key)
                print "WARNING!!", key, "not found", ref[key]
                always_fails = True
                value = ref[key]
            else:
                value = map[key]
            if isinstance(tols,dict) and key in tols:
                (failed, newtols) = compare(value, ref[key], tols[key], always_fails)
            # def tols is rigorously a one-level only dictionary
            elif key in def_tols:
                (failed, newtols) = compare(value, ref[key], def_tols[key], always_fails)
            else:
                (failed, newtols) = compare(value, ref[key], always_fails=always_fails)
            # add to the tolerance dictionary a failed result
            if failed:
                if isinstance(tols,dict) and key in tols:
                    if isinstance(newtols,dict):
                        if isinstance(tols[key],dict):
                            tols[key].update(newtols)
                        else:
                            tols[key] = newtols
                    elif isinstance(newtols,list):
                        tols[key] = newtols
                    else:
                        tols[key] = max(newtols, tols[key])
                elif isinstance(tols,dict):
                    tols[key] = newtols
    return (len(tols) > 0, tols)


def compare_scl(scl, ref, tols, always_fails=False):
    "Compare the scalars and retrurn the tolerance it the results are ok"
    global failed_checks, discrepancy, biggest_tol
    failed = always_fails
    ret = (failed, None)
    #  print scl,ref,tols, type(ref), type(scl)
    # eliminate the character variables
    if isinstance(ref,str):
        if not(scl == ref):
            ret = (True, scl)
    elif not(always_fails):
        # infinity case
        if scl == ref:
            failed = False
            diff = 0.
        else:
            try:
                diff = math.fabs(scl - ref)
                ret_diff = diff
                if tols is None:
                    failed = not(diff <= epsilon)
                else:
                    failed = not(diff <= tols)
            except TypeError:
                ret_diff = "NOT SAME KIND"
                diff = 0.
                failed = True
        discrepancy = max(discrepancy, diff)
        #  if (discrepancy > 1.85e-6):
        #      print 'test',scl,ref,tols,discrepancy,failed
        #      sys.exit(1)
        if not(failed):
            if tols is None:
                ret = (always_fails, None)
            else:
                ret = (True, tols)
        else:
            ret = (True, ret_diff)
            if tols is not None:
                biggest_tol = max(biggest_tol, math.fabs(tols))
    if failed:
        if failed_checks < 20:
            print 'fldiff_failure; val, ref, tol, diff, bigtol', scl, ref, tols, discrepancy, biggest_tol
        failed_checks += 1
    return ret


def document_report(hostname, tol, biggest_disc, nchecks, leaks, nmiss, miss_it, timet, message=""):
    "Report about the document"
    results = {}
    failure_reason = None
    #  disc=biggest_disc
    if nchecks > 0 or leaks != 0 or nmiss > 0:
        if leaks != 0:
            failure_reason = "Memory Leak"
        elif nmiss > 0:
            failure_reason = "Information"
        elif tol == -1 and "No such file" in message:
            failure_reason = "Missing File"
        elif tol == -1 and "while parsing" in message:
            failure_reason = "Yaml Standard"
        elif tol == 0 and biggest_disc == 0 and timet == 0:
            failure_reason = "Yaml Standard"
        elif hostname == "None":
            failure_reason = "Crash"
        else:
            failure_reason = "Difference"
    results["Platform"] = hostname
    results["Test succeeded"] = nchecks == 0 and nmiss == 0 and leaks == 0
    if failure_reason is not None:
        results["Failure reason"] = failure_reason
    results["Maximum discrepancy"] = biggest_disc
    results["Maximum tolerance applied"] = tol
    results["Seconds needed for the test"] = round(timet,2)
    if (nmiss > 0):
        results["Missed Reference Items"] = miss_it
    #
    return results


import yaml_hl


class Pouet:
    """Class used to define options in order to hightlight the YAML output by mean of yaml_hl"""
    def __init__(self, input="report"):
        # Define a temporary file
        self.input = input
        self.output = None
        self.style = "ascii"
        self.config = os.path.join(path, 'yaml_hl.cfg')


# Color options
options = Pouet()
# Create style (need to be in __main__)
Style = yaml_hl.Style


def parse_arguments():
    "Parse the arguments"
    parser = optparse.OptionParser(
        "This script is used to compare two yaml outputs with respect to a tolerance file given. usage: fldiff_yaml.py <options>")
    parser.add_option('-r', '--reference', dest='ref', default=None,  # sys.argv[1],
                      help="reference yaml stream", metavar='REFERENCE')
    parser.add_option('-d', '--data', dest='data', default=None,  # sys.argv[2],
                      help="yaml stream to be compared with reference", metavar='DATA')
    parser.add_option('-t', '--tolerances', dest='tols', default=None,  # sys.argv[3],
                      help="File of the tolerances used for comparison", metavar='TOLS')
    parser.add_option('-o', '--output', dest='output', default="/dev/null",  # sys.argv[4],
                      help="set the output file (default: /dev/null)", metavar='FILE')
    parser.add_option('-l', '--label', dest='label', default=None,
                      help="Define the label to be used in the tolerance file to override the default", metavar='LABEL')
    # Return the parsing
    return parser

def highlight_iftty(options):
    hl = yaml_hl.YAMLHighlight(options)
    if os.isatty(hl.output.fileno()):
        hl.highlight()
    else:
        hl.output.write(hl.input.read().encode('utf-8'))


def fatal_error(reports, message='Error in reading datas, Yaml Standard violated or missing file'):
    "Fatal Error: exit after writing the report, assume that the report file is already open)"
    global options
    print message
    finres = document_report('None', -1., 0., 1, 0, 0, 0, 0,message=message)
    reports.write(
        yaml.dump(finres, default_flow_style=False, explicit_start=True))
    newreport = open("report", "w")
    newreport.write(
        yaml.dump(finres, default_flow_style=False, explicit_start=True))
    newreport.close()
    highlight_iftty(options)
    #hl = yaml_hl.YAMLHighlight(options)
    #hl.highlight()
    sys.exit(0)

    
if __name__ == "__main__":
    parser = parse_arguments()
    (args, argtmp) = parser.parse_args()


# args=parse_arguments()
# print args.ref,args.data,args.output
#datas      = [a for a in yaml.load_all(open(args.data, "r"), Loader = yaml.CLoader)]
references = [a for a in yaml.load_all(
    open(args.ref, "r").read(), Loader=yaml.CLoader)]
try:
    datas = [a for a in yaml.load_all(
        open(args.data, "r").read(), Loader=yaml.CLoader)]
except Exception, e:
    reports = open(args.output, "w")
    fatal_error(reports, message=str(e))

if args.tols:
    try:
        orig_tols = yaml.load(open(args.tols, "r").read(), Loader=yaml.CLoader)
    except Exception, e:
        reports = open(args.output, "w")
        fatal_error(reports, message=str(e))
else:
    orig_tols = dict()

# take default value for the tolerances
try:
    def_tols = orig_tols["Default tolerances"]
    try:
        keys_to_ignore = orig_tols["Keys to ignore"]
    except:
        keys_to_ignore = []
    try:
        patterns_to_ignore = orig_tols["Patterns to ignore"]
    except:
        patterns_to_ignore = []
except:
    def_tols = {}
    keys_to_ignore = []
    patterns_to_ignore = []

# override the default tolerances with the values which are written in the
# label
extra_tols = {}
if args.label is not None and args.label is not '':
    try:
        extra_tols = orig_tols[args.label]
        # adding new keys to ignore
        try:
            keys_to_ignore += extra_tols["Keys to ignore"]
            del extra_tols["Keys to ignore"]
        except:
            print 'Label "%s": No new keys to ignore' % args.label
        # adding new patterns to ignore
        try:
            patterns_to_ignore += extra_tols["Patterns to ignore"]
            del extra_tols["Patterns to ignore"]
        except:
            print 'Label "%s": No new patterns to ignore' % args.label
        # adding new tolerances and override default ones
        try:
            def_tols.update(extra_tols)
        except:
            print 'Label "%s": No new tolerances' % args.label
        # eliminate particular case
        del orig_tols[args.label]
    except:
        print 'Label "%s" not found in tolerance file' % args.label

# determine generic tolerance
try:
    epsilon = orig_tols["Default tolerances"]["Epsilon"]
except:
    epsilon = 0

poplist = []
for k in range(len(keys_to_ignore)):
    if keys_to_ignore[k].find('*') > -1:
        poplist.append(k)
        patterns_to_ignore.append(keys_to_ignore[k].partition('*')[0])
# print poplist
ipopped = 0
for k in poplist:
    keys_to_ignore.pop(k - ipopped)
    ipopped += 1

if len(patterns_to_ignore) > 0:
    orig_tols["Patterns to ignore"] = patterns_to_ignore

# print 'Epsilon tolerance',epsilon
# print 'Ignore',keys_to_ignore,'Patterns',patterns_to_ignore

failed_documents = 0
reports = open(args.output, "w")
max_discrepancy = 0.
leak_memory = 0
total_misses = 0
total_missed_items = []
time = 0.
biggest_tol = epsilon
try:
    hostname = datas[0]["Root process Hostname"]
except:
    hostname = 'unknown'

if len(references) != len(datas):
    fatal_error(reports,
                message='Error, number of documents differ between reference (%d) and data (%d)' % (len(references), len(datas)))

for i in range(len(references)):
    tols = {}  # copy.deepcopy(orig_tols)
    #global variable!
    failed_checks = 0
    docmiss = 0
    docmiss_it = []
    discrepancy = 0.
    reference = references[i]
    # this executes the fldiff procedure
    #compare(datas[i], reference, tols)
    try:
        data = datas[i]
        if data is not None:
            compare(data, reference, tols)
        else:
            fatal_error(reports, message='Empty document!')
    except Exception, e:
        fatal_error(reports, message=str(e))
    try:
        doctime = data["Timings for root process"]["Elapsed time (s)"]
    except:
        doctime = 0
    try:
        docleaks = data["Memory Consumption Report"]["Remaining Memory (B)"]
    except:
        docleaks = 0
    #  print "failed checks",failed_checks,"max diff",discrepancy
    max_discrepancy = max(discrepancy, max_discrepancy)
    # print total time
    time += doctime
    # print remaining memory
    leak_memory += docleaks
    total_misses += docmiss
    total_missed_items.append(docmiss_it)
    if failed_checks > 0 or docleaks > 0:
        failed_documents += 1
        # optional
        sys.stdout.write(
            yaml.dump(tols, default_flow_style=False, explicit_start=True))
    newreport = open("report", "w")
    newreport.write(yaml.dump(document_report(hostname, biggest_tol, discrepancy, failed_checks, docleaks, docmiss, docmiss_it, doctime),
                              default_flow_style=False, explicit_start=True))
    newreport.close()
    reports.write(open("report", "rb").read())
    #highlight report file if possible
    highlight_iftty(options)
    sys.stdout.write("#Document: %2d, failed_checks: %d, Max. Diff. %10.2e, missed_items: %d memory_leaks (B): %d, Elapsed Time (s): %7.2f\n" %
                     (i, failed_checks, discrepancy, docmiss, docleaks, doctime))


# Create dictionary for the final report
if len(references) > 1:
    finres = document_report(hostname, biggest_tol, max_discrepancy,
                             failed_documents, leak_memory, total_misses, total_missed_items, time)
    newreport = open("report", "w")
    newreport.write(
        yaml.dump(finres, default_flow_style=False, explicit_start=True))
    newreport.close()
    reports.write(open("report", "rb").read())
    highlight_iftty(options)

# Then remove the file "report" (temporary file)
os.remove("report")

sys.exit(0)
