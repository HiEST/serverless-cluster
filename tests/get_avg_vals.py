import numpy as np
import matplotlib.pyplot as plt
import pandas as pd 

NUM_TESTS = 100

LOCAL_VOL = 1
LOCAL_VOL_RNOBUFF = 0
LOCAL_VOL_WFLASH = 0
LOCAL_MEM_VOL = 0
LOCAL_HPATH = 0
REMOTE_NFS_VOL = 0
REMOTE_NFS_VOL_RNOBUFF = 0

LOG_SCALE = 0

COMPUTE_AVG_TIMES = 0
COMPUTE_THROUGHPUTS = 1

SEPARATE_PLOTS = 1

dims = ["1 KB", 
        "2 KB",
        "4 KB",
        "8 KB",
        "16 KB",
        "32 KB", 
        "64 KB",
        "128 KB", 
        "256 KB", 
        "512 KB",
        "1 MB", 
        "2 MB",
        "4 MB",
        "8 MB",
        "16 MB",
        "32 MB", 
        "64 MB",
        "128 MB", 
        "256 MB", 
        "512 MB",
        "1 GB",
        "2 GB"
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

def compute_avgs(filename):
    with open(filename, "r") as rf:
        # Read all the times
        rcontent = rf.readlines()
        # Sum up all the times
        rsum = 0
        for line in rcontent:
            rsum = rsum + float(line)
        # Computer average value
        avg = rsum / NUM_TESTS
        return avg

def compute_throughput(file, dim):
    # Get average times 
    avg_time = compute_avgs(file)
    # Get number of input number of bits 
    num_bits = compute_num_bits(dim)
    # Get the throughput in Mbps
    print(num_bits)
    print(num_bits/8)
    th = ((num_bits/8)/avg_time)*pow(10,-6)
    print(th)
    return th

def compute_list(type, op):
    avgs = []
    for it, dim in enumerate(dims):
        print("---------------- %s ---------------- " % dim)
        # Set the filename for the current dimension
        file = 'times/py_old/' + type + '/' + op + '/' + dim.replace(" ", "") + 'times.txt'
        # Compute the read average time
        if COMPUTE_AVG_TIMES:
            avgs.append(compute_avgs(file))
        else:
            avgs.append(compute_throughput(file, dim))
    return avgs

def compute_r_w_lists(type):
    read_avgs = compute_list(type, 'read')
    write_avgs = compute_list(type, 'write')
    return read_avgs, write_avgs

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

def plot_dataframes(type, read_avgs, write_avgs, ax, color_r, color_w):
    ax = plot_dataframe(type, 'read', read_avgs, ax, color_r)
    ax = plot_dataframe(type, 'write', write_avgs, ax, color_w)
    return ax

def construct_out_file_name():
    out_file_name = "plots/"
    if LOCAL_VOL and LOCAL_MEM_VOL:
        out_file_name+='locals_'
    else:
        if LOCAL_VOL:
            out_file_name+='localvol_'
        if LOCAL_VOL_RNOBUFF:
            out_file_name+='localvolrnobuff_'
        if LOCAL_VOL_WFLASH:
            out_file_name+='localvolwflash_'
        if LOCAL_MEM_VOL:
            out_file_name+='localmem_'
    if REMOTE_NFS_VOL and REMOTE_NFS_VOL_RNOBUFF:
        out_file_name+='remotes_'
    else:
        if REMOTE_NFS_VOL:
            out_file_name+='remotenfsvol_'
        if REMOTE_NFS_VOL_RNOBUFF:
            out_file_name+='remotenfsvolrnobuff_'
    if COMPUTE_AVG_TIMES:
        if LOG_SCALE:
            out_file_name+='times_log'
        else:
            out_file_name+='times'
    else:
        out_file_name+='throughputs'
    if SEPARATE_PLOTS:
        out_file_name+='_sep'
    out_file_name+='_plot.pdf'
    return out_file_name

# Create the output figure and axes
if SEPARATE_PLOTS:
    fig, axarr = plt.subplots(2)
else:
    fig, ax = plt.subplots()

if LOCAL_VOL:
    print("LOCAL VOL:")
    # Compute read and write avgs
    read_avgs, write_avgs = compute_r_w_lists('local_vol')
    # Plot the read and write avgs
    if SEPARATE_PLOTS:
        axarr = plot_dataframes('local vol', read_avgs, write_avgs, axarr, 'palevioletred', 'lightpink')
    else:
        ax = plot_dataframes('local vol', read_avgs, write_avgs, ax, 'paletvioletred', 'lightpink')

if LOCAL_VOL_RNOBUFF:
    print("LOCAL VOL RNOBUFF:")  
    # Compute read avgs
    read_avgs = compute_list('local_vol_rnobuff', 'read')
    # Plot the read avgs
    if SEPARATE_PLOTS:
        axarr = plot_dataframe('local vol rnobuff', 'read', read_avgs, axarr, 'darkseagreen')
    else:
        ax = plot_dataframe('local vol rnobuff', 'read', read_avgs, ax, 'darkseagreen')

if LOCAL_VOL_WFLASH:
    print("LOCAL VOL WFLASH:")  
    # Compute read avgs
    write_avgs = compute_list('local_vol_wflash', 'write')
    # Plot the read avgs
    if SEPARATE_PLOTS:
        axarr = plot_dataframe('local vol wflash', 'write', write_avgs, axarr, 'lightseagreen')
    else:
        ax = plot_dataframe('local vol wflash', 'write', write_avgs, ax, 'lightseagreen')

if LOCAL_MEM_VOL:
    print("LOCAL MEM VOL:")
    # Compute read and write avgs
    read_avgs, write_avgs = compute_r_w_lists('local_mem')
    # Plot the read and write avgs
    if SEPARATE_PLOTS:
        axarr = plot_dataframes('local mem', read_avgs, write_avgs, axarr, 'tan', 'wheat')
    else:
        ax = plot_dataframes('local mem', read_avgs, write_avgs, ax,'tan','wheat')

if REMOTE_NFS_VOL:
    print("REMOTE NFS VOL:")
    # Compute read and write avgs
    read_avgs, write_avgs = compute_r_w_lists('remote_nfs')
    # Plot the read and write avgs
    if SEPARATE_PLOTS:
        axarr = plot_dataframes('remote nfs vol', read_avgs, write_avgs, axarr, 'salmon', 'lightsalmon')
    else:
        ax = plot_dataframes('remote nfs vol', read_avgs, write_avgs, ax, 'salmon', 'lightsalmon')

if REMOTE_NFS_VOL_RNOBUFF:
    print("REMOTE NFS RNOBUFF:")
    # Compute read avgs
    read_avgs = compute_list('remote_nfs_rnobuff', 'read')
    # Plot the read avgs
    if SEPARATE_PLOTS:
        axarr = plot_dataframe('remote nfs nobuff', 'read', read_avgs, axarr, 'tab:brown')
    else:
        ax = plot_dataframe('remote nfs nobuff', 'read', read_avgs, ax, 'tab:brown')

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

if COMPUTE_AVG_TIMES:
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

