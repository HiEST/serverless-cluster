import numpy as np
import matplotlib.pyplot as plt
import pandas as pd 
from statistics import median

LOCAL_MEM = 1
LOCAL_VOL_FULL = 0
LOCAL_VOL_FULL_MOPS = 0
LOCAL_RNOBUFF = 0
REMOTE_NFS_FULL = 0
REMOTE_NFS_FULL_SAMENODE  = 0
REMOTE_NFS_FULL_MOPS = 0
REMOTE_NFS_RNOBUFF = 0

LOG_SCALE = 0

COMPUTE_MEDIAN_TIMES = 0
COMPUTE_THROUGHPUTS = 1

SEPARATE_PLOTS = 1

dims = ["1 KB", 
        "4 KB",
        "16 KB",
        "64 KB",
        "256 KB", 
        "1 MB", 
        "4 MB",
        "16 MB",
        "64 MB",
        "256 MB", 
        "1 GB",

]

num_dims = len(dims)

def compute_num_bits(dim):
    dim_s = dim.split()
    val = int(dim_s[0])
    d = dim_s[1]
    switcher={
            "KB": val*1024*8,
            "MB": val*1024*1024*8,
            "GB": val*1024*1024*1024*8
    }
    return switcher.get(d, "ERROR: Dimension %s not allowed!" % d)

def compute_median(filename):
    with open(filename, "r") as f:
        # Read all the times
        content = f.readlines()
        # Sum up all the times
        m = median([float(val) for val in content])
        return m

def compute_throughput(file, dim):
    # Get median times 
    median_time = compute_median(file)
    # Get number of input number of bits 
    num_bits = compute_num_bits(dim)
    # Get the throughput in Mbps
    th = ((num_bits/8)/median_time)*pow(10,-6)
    print(th)
    return th

def compute_list(type, op, el=None):
    avgs = []
    for it, dim in enumerate(dims):
        print("---------------- %s %s ---------------- " % (dim, op))
        # Set the filename for the current dimension
        if el != None:
            file = 'times/py/' + type + '/' + op + '/' + dim.replace(" ", "") + '_' + el + '_times.txt'
        else:
            file = 'times/py/' + type + '/' + op + '/' + dim.replace(" ", "") + 'times.txt'
        # Compute the read median time
        if COMPUTE_MEDIAN_TIMES:
            avgs.append(compute_median(file))
        else:
            avgs.append(compute_throughput(file, dim))
    return avgs

def compute_r_w_lists(type, mops=False, el=None):
    if mops:
        read_medians = compute_list(type, 'read', el)
        write_medians = compute_list(type, 'write', el)
    else:
        read_medians = compute_list(type, 'read')
        write_medians = compute_list(type, 'write')
    return read_medians, write_medians

def plot_dataframe(type, op, avgs, ax, color):
    # Create the read and write dataframes 
    df = pd.DataFrame({"dim": dims, "avg": avgs})
    # Set the labels
    label_op = type + ' ' + op
    if op == 'read':
        marker_op='o'
        index = 0;
    else:
        marker_op='D'
        index = 1;
    # Plot the dataframes
    if SEPARATE_PLOTS:
        ax[index].plot(np.arange(len(df['dim'])), df['avg'], markersize=5, color=color, marker=marker_op, linewidth=1, label=label_op)
    else:
        ax.plot(np.arange(len(df['dim'])), df['avg'], markersize=5, color=color, marker=marker_op, linewidth=1, label=label_op)
    return ax

def plot_dataframes(type, read_medians, write_medians, ax, color_r, color_w):
    ax = plot_dataframe(type, 'read', read_medians, ax, color_r)
    ax = plot_dataframe(type, 'write', write_medians, ax, color_w)
    return ax

def construct_out_file_name():
    out_file_name = "plots/"
    if LOCAL_MEM and LOCAL_VOL_FULL and LOCAL_VOL_FULL_MOPS and LOCAL_RNOBUFF:
        out_file_name+='locals_'
    else:
        if LOCAL_MEM:
            out_file_name+='localmemvol_'
        if LOCAL_VOL_FULL:
            out_file_name+='localvolfull_'
        if LOCAL_VOL_FULL_MOPS:
            out_file_name+='localvolfullmops_'
        if LOCAL_RNOBUFF:
            out_file_name+='localvolrnobuff_'
    if REMOTE_NFS_FULL and REMOTE_NFS_FULL_SAMENODE and REMOTE_NFS_FULL_MOPS and REMOTE_NFS_RNOBUFF:
        out_file_name+='remotes_'
    else:
        if REMOTE_NFS_FULL:
            out_file_name+='remotenfsvolfull_'
        if REMOTE_NFS_FULL_SAMENODE:
            out_file_name+='remotenfsvolfullsamenode_'
        if REMOTE_NFS_FULL_MOPS:
            out_file_name+='remotenfsvolfullmops_'
        if REMOTE_NFS_RNOBUFF:
            out_file_name+='remotenfsvolrnobuff_'
    if COMPUTE_MEDIAN_TIMES:
        if LOG_SCALE:
            out_file_name+='med_times_log'
        else:
            out_file_name+='med_times'
    else:
        out_file_name+='med_throughputs'
    if SEPARATE_PLOTS:
        out_file_name+='_sep'
    out_file_name+='_plot.pdf'
    return out_file_name

# Create the output figure and axes
if SEPARATE_PLOTS:
    fig, axarr = plt.subplots(2)
else:
    fig, ax = plt.subplots()

if LOCAL_MEM:
    print("LOCAL MEM:")
    # Compute read and write avgs
    read_medians, write_medians = compute_r_w_lists('local_mem')
    # Plot the read and write avgs
    if SEPARATE_PLOTS:
        axarr = plot_dataframes('local mem', read_medians, write_medians, axarr, 'tan', 'wheat')
    else:
        ax = plot_dataframes('local mem', read_medians, write_medians, ax,'tan','wheat')

if LOCAL_VOL_FULL:
    print("LOCAL VOL FULL:")
    # Compute read and write avgs
    read_medians, write_medians = compute_r_w_lists('local_vol_full')
    # Plot the read and write avgs
    if SEPARATE_PLOTS:
        axarr = plot_dataframes('local full', read_medians, write_medians, axarr, 'royalblue', 'lightsteelblue')
    else:
        ax = plot_dataframes('local full', read_medians, write_medians, ax, 'royalblue', 'lightsteelblue')

if LOCAL_VOL_FULL_MOPS:
    print("LOCAL VOL FULL MOPS:")
    # Compute read avgs
    print("FIRST BANDWIDTHS:")
    read_medians_first, write_medians_first = compute_r_w_lists('local_vol_full_mops', True, 'first')
    print("NEXT BANDWIDTHS:")
    read_medians_others, write_medians_others = compute_r_w_lists('local_vol_full_mops', True, 'others')
    # Plot the read and write avgs
    if SEPARATE_PLOTS:
        axarr = plot_dataframes('local mops first', read_medians_first, write_medians_first, axarr, 'tan', 'wheat')
        axarr = plot_dataframes('local mops first', read_medians_others, write_medians_others, axarr, 'orangered', 'tomato')
    else:
        ax = plot_dataframes('local mops first', read_medians_first, write_medians_first, ax, 'tan', 'wheat')
        ax = plot_dataframes('local mops others', read_medians_others, write_medians_others, ax, 'orangered', 'tomato')

if LOCAL_RNOBUFF:
    print("LOCAL RNOBUFF:")  
    # Compute read avgs
    read_medians = compute_list('local_vol_rnobuff', 'read')
    # Plot the read avgs
    if SEPARATE_PLOTS:
        axarr = plot_dataframe('local rnobuff', 'read', read_medians, axarr, 'darkseagreen')
    else:
        ax = plot_dataframe('local rnobuff', 'read', read_medians, ax, 'darkseagreen')

if REMOTE_NFS_FULL:
    print("REMOTE NFS FULL VOL:")
    # Compute read and write avgs
    read_medians, write_medians = compute_r_w_lists('remote_nfs_vol_full')
    # Plot the read and write avgs
    if SEPARATE_PLOTS:
        axarr = plot_dataframes('remote nfs full', read_medians, write_medians, axarr, 'tan', 'wheat')
    else:
        ax = plot_dataframes('remote nfs full', read_medians, write_medians, ax, 'tan', 'wheat')

if REMOTE_NFS_FULL_SAMENODE:
    print("REMOTE NFS FULL VOL SAMENODE:")
    # Compute read and write avgs
    read_medians, write_medians = compute_r_w_lists('remote_nfs_vol_full_samenode')
    # Plot the read and write avgs
    if SEPARATE_PLOTS:
        axarr = plot_dataframes('remote nfs full samenode', read_medians, write_medians, axarr, 'darkolivegreen', 'olivedrab')
    else:
        ax = plot_dataframes('remote nfs full same node', read_medians, write_medians, ax, 'darkolivegreen', 'olivedrab')

if REMOTE_NFS_FULL_MOPS:
    print("REMOTE NFS FULL MOPS:")
    # Compute read avgs
    print("FIRST BANDWIDTHS:")
    read_medians_first, write_medians_first = compute_r_w_lists('remote_nfs_vol_full_mul', True, 'first')
    print("NEXT BANDWIDTHS:")
    read_medians_others, write_medians_others = compute_r_w_lists('remote_nfs_vol_full_mul', True, 'others')
    # Plot the read and write avgs
    if SEPARATE_PLOTS:
        axarr = plot_dataframes('remote mops first', read_medians_first, write_medians_first, axarr, 'tan', 'wheat')
        axarr = plot_dataframes('remote mops first', read_medians_others, write_medians_others, axarr, 'orangered', 'tomato')
    else:
        ax = plot_dataframes('remote mops first', read_medians_first, write_medians_first, ax, 'tan', 'wheat')
        ax = plot_dataframes('remote mops others', read_medians_others, write_medians_others, ax, 'orangered', 'tomato')

if REMOTE_NFS_RNOBUFF:
    print("REMOTE NFS RNOBUFF:")
    # Compute read avgs
    read_medians = compute_list('remote_nfs_vol_rnobuff', 'read')
    # Plot the read avgs
    if SEPARATE_PLOTS:
        axarr = plot_dataframe('remote nfs nobuff', 'read', read_medians, axarr, 'tab:brown')
    else:
        ax = plot_dataframe('remote nfs nobuff', 'read', read_medians, ax, 'tab:brown')

if SEPARATE_PLOTS:
    # Create the read and write plots separately
    for i in range(2):
        axarr[i].set_xticks(np.arange(len(dims)))
        axarr[i].set_xticklabels(dims, rotation='vertical')
        axarr[i].legend(loc='lower right')
        if LOG_SCALE:
            axarr[i].set_yscale('log')
else:
    # Create one plot for read and write
    ax.set_xticks(np.arange(len(dims)))
    ax.set_xticklabels(dims, rotation='vertical')
    if LOG_SCALE:
        ax.set_yscale('log')
    plt.legend(loc='upper left')

if COMPUTE_MEDIAN_TIMES:
    # Add y-axis time label 
    if LOG_SCALE:
        fig.text(0.002, 0.5, 'Time [s](log scale)', va='center', rotation='vertical')
    else:
        fig.text(0.002, 0.5, 'Time [s]', va='center', rotation='vertical')
else:
    # Add y-axis throughput label
    fig.text(0.002, 0.5, 'Throughput [MB/s]', va='center', rotation='vertical')

# Add x-axis dimension label
fig.text(0.5, 0.01, 'Dimension', va='center')

# Configure the figure layout
plt.tight_layout()

# Get the output figure name
out_fname = construct_out_file_name()

# Save figure
fig.savefig(out_fname)
