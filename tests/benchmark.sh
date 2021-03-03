#!/bin/bash

NUM_ITS=100

LOCAL_VOL=0
LOCAL_VOL_RNOBUFF=0
LOCAL_VOL_WFLASH=0
LOCAL_MEM_VOL=0
LOCAL_HPATH=1
REMOTE_NFS_VOL=0
REMOTE_NFS_VOL_RNOBUFF=0

dims=( "1 KB"
	"2 KB"	
	"4 KB" 
	"8 KB" 
	"16 KB" 
	"32 KB" 
	"64 KB" 
	"128 KB" 
	"256 KB" 
	"512 KB" 
	"1 MB"
	"2 MB" 
	"4 MB" 
	"8 MB" 
	"16 MB"
	"32 MB"
	"64 MB"
	"128 MB"
    "256 MB" 
	"512 MB"
	"1 GB"
	"2 GB"
)	


num_bytes=0

compute_num_bytes(){
	# Get the value and the dimension
	stringarray=( $1 )
	val=${stringarray[0]}
	dim=${stringarray[1]}
    # Return the actual number of bytes
    case "$dim" in
		"B") num_bytes=$val
		;;
		"KB") num_bytes=$(($val*1024))
		;;
		"MB") num_bytes=$(($val*1024*1024))
		;;
		"GB") num_bytes=$(($val*1024*1024*1024))
		;;
		*) echo "ERROR: Dimension $dim not allowed!" 
		exit 1
		;;
	esac
}

pipeline_yaml_path=""
rtimes_folder=""
wtimes_folder=""

# Check if a configuration is given, and if it is just one per time
if [ $((LOCAL_MEM_VOL + LOCAL_VOL + LOCAL_HPATH + LOCAL_VOL_RNOBUFF + REMOTE_NFS_VOL + REMOTE_NFS_VOL_RNOCACHE)) -gt 1 ]
then
	echo "ERROR: You can run one configuration tests per time!"
	exit 1
fi

# Set the file names
if [[ $LOCAL_MEM_VOL == 1 ]]
then
	pipeline_yaml_path="files/py_rw_ops_eph_bench_pipeline_tasks.yaml"
	rtimes_folder="times/py/local_mem_vol/read/"
	wtimes_folder="times/py/local_mem_vol/write/"
elif [[ $LOCAL_VOL_RNOBUFF == 1 ]]
then
	pipeline_yaml_path="files/py_r_nocache_op_bench_pipeline_task.yaml"
	rtimes_folder="times/py/local_vol_rnobuff/read/"
elif [[ $LOCAL_VOL_WFLASH == 1 ]]
then
    pipeline_yaml_path="files/py_w_flash_op_bench_pipeline_task.yaml"
    wtimes_folder="times/py/local_vol_wflash/write/"
elif [[ $LOCAL_VOL == 1 || $LOCAL_HPATH == 1 || $REMOTE_NFS_VOL == 1 ]]
then 
	pipeline_yaml_path="files/py_rw_ops_bench_pipeline_tasks.yaml" 
	if [[ $LOCAL_VOL == 1 ]]
	then
		rtimes_folder="times/py/local_vol/read/"
		wtimes_folder="times/py/local_vol/write/"
	elif [[ $LOCAL_HPATH == 1 ]]
	then
		rtimes_folder="times/py/local_hpath/read/"
		wtimes_folder="times/py/local_hpath/write/"
	elif [[ $REMOTE_NFS_VOL == 1 ]]
	then	
		rtimes_folder="times/py/remote_nfs_vol/read/"
		wtimes_folder="times/py/remote_nfs_vol/write/"
    fi
elif [[ $REMOTE_NFS_VOL_RNOBUFF == 1 ]]
then
    pipeline_yaml_path="files/py_r_nobuff_op_bench_pipeline_tasks.yaml"
	rtimes_folder="times/py/remote_nfs_rnobuff/read/"
else
	echo "ERROR: A configuration is required!"
	exit 1
fi

# Create output folders
if [[ $LOCAL_VOL_WFLASH == 0 ]]
then
    mkdir -p $rtimes_folder
fi
if [[ $LOCAL_VOL_RNOBUFF == 0 ]]
then
	mkdir -p $wtimes_folder
fi

exec 5>&1

# Set pv and pipelinerun files
pv_yaml=""
plr_yaml=""
if [[ $LOCAL_VOL == 1 || $LOCAL_HPATH == 1 || $LOCAL_VOL_RNOBUFF == 1 || $LOCAL_VOL_WFLASH == 1 ]]
then	
	if [[ $LOCAL_VOL == 1 || $LOCAL_VOL_RNOBUFF == 1 || $LOCAL_VOL_WFLASH == 1 ]]
	then
		pv_yaml="../storage_objs/persistentVolumeTektonVol.yaml"
	else
		pv_yaml="../storage_objs/persistentVolumeTektonHostPath.yaml"
	fi
	plr_yaml="files/pipelinerun.yaml"
elif [[ $LOCAL_MEM_VOL == 1 ]]
then
	plr_yaml="files/pipelinerunEmptyDir.yaml"
elif [[ $REMOTE_NFS_VOL == 1 ]]
then
	pv_yaml="../storage_objs/persistentVolumeTektonNFS.yaml"
	plr_yaml="files/pipelinerunNFS.yaml"
elif [[ $REMOTE_NFS_VOL_RNOBUFF == 1 ]]
then
    pv_yaml="../storage_objs/persistentVolumeTektonNFS.yaml"
    plr_yaml="files/pipelinerunNFSrnobuff.yaml"
fi

# Run the tests
for i in "${dims[@]}"; do
	if [[ $LOCAL_VOL == 1 ]]
	then 
		echo "***************************** LOCAL VOL BENCHMARK ON $i ******************************"
    elif [[ $LOCAL_VOL_RNOBUFF == 1 ]]
    then
		echo "**************************** LOCAL VOL RNOBUFF BENCHMARK ON $i ***********************"
    elif [[ $LOCAL_VOL_WFLASH == 1 ]]
    then
		echo "**************************** LOCAL VOL WFLASH BENCHMARK ON $i ***********************"
    elif [[ $LOCAL_MEM_VOL == 1 ]]
	then
		echo "*************************** LOCAL MEM VOL BENCHMARK ON $i ***************************"
		elif [[ $LOCAL_HPATH == 1 ]]
	then
		echo "************************** LOCAL HOSTPATH BENCHMARK ON $i ****************************"
	elif [[ $REMOTE_NFS_VOL == 1 ]]
	then
		echo "************************** REMOTE NFS VOL BENCHMARK ON $i *****************************"
	else
		echo "********************** REMOTE NFS VOL RNOBUFF BENCHMARK ON $i *************************" 
	fi
	# Modifiy the pipeline tasks with the proper dimension
	cp $pipeline_yaml_path files/pipeline.yaml
	if [[ $LOCAL_VOL_RNOBUFF == 0 ]]
	then
		compute_num_bytes "$i"
		sed -i "s/temp_val/${num_bytes}/g" files/pipeline.yaml
	fi
	dim_nospace=$(echo $i | sed "s/ //g")
	sed -i "s/array.txt/${dim_nospace}array.txt/g" files/pipeline.yaml
	# Deploy the pipeline along with its tasks
	out=$(kubectl apply -f files/pipeline.yaml 2> /dev/null | tee >(cat - >&5))
	p_obj=""
	t_objs=()
	for obj in $out; do
		if [[ $obj == *"/"* ]];then
			obj_name=$(echo "$obj" | cut -d "/" -f2- | awk '{print $1}')
			if [[ $obj_name == *"pipeline"* ]];then
				p_obj=$obj_name
			else
				t_objs+="$obj_name "
			fi
		fi
	done
	# Create the file name and relative paths
	filename="${dim_nospace}times.txt"
	if [[ $LOCAL_VOL_RNOBUFF == 0 ]]
	then
		write_fpath="${wtimes_folder}${filename}"
	fi
    if [[ $LOCAL_VOL_WFLASH == 0 ]]
    then
	    read_fpath="${rtimes_folder}${filename}"
    fi
	
	# Run multiple times to get a fair r/w througput value
	for (( j=1; j<=$NUM_ITS; ++j)); do
		echo "RUNNING $j/$NUM_ITS ITERATION.."
		if [[ $LOCAL_VOL == 1 ||  $LOCAL_HPATH == 1 || $REMOTE_NFS_VOL == 1 || $LOCAL_VOL_RNOBUFF == 1 ]]
		then
			# Deploy the pv
			out=$(kubectl apply -f $pv_yaml 2> /dev/null | tee >(cat - >&5))
			pv_obj=( $(echo "$out" | cut -d "/" -f2- | awk '{print $1}'))
		fi
		# Deploy the pipelinerun
		out=$(kubectl create -f $plr_yaml 2> /dev/null | tee >(cat - >&5))
		prun_obj=( $(echo "$out" | cut -d "/" -f2- | awk '{print $1}'))
        # Wait for the pipeline to start
        array=($out)
        while [ ${#array[@]} -lt 8 ]
        do
            out=$(kubectl get pipelineruns 2> /dev/null)
            array=($out)
        done
		# Read the pipelinerun logs to extract the read and write throughput
		echo "Pipeline is still running.."
		out=$(kubectl get pipelineruns 2> /dev/null)
		set -- $out
		while [ $7 != 'True' -a $8 != 'Succeded' ]; do
			if [ $8 == 'False' ]
		       	then
				echo "ERROR: Pipelinerun has failed!"
				exit
			fi	
			out=$(kubectl get pipelineruns 2> /dev/null)
			set -- $out
		done	
		echo "Pipeline has finished!"
		tkn pipelinerun logs $prun_obj > out.log
		times=$(grep -hnr "seconds" out.log |  awk '{print $5}')
		rm out.log
		echo "Writing times on output files.."
		if [[ $LOCAL_VOL_RNOBUFF == 0 ]]
		then
			echo $times | awk '{print $1}' >> $write_fpath
			echo $times | awk '{print $2}' >> $read_fpath 
		else
			echo $times >> $read_fpath
		fi
		# Delete the pipelinerun
		kubectl delete pipelinerun $prun_obj 2> /dev/null
		# Delete the pv
		if [[ $LOCAL_MEM_VOL == 0 ]]
		then
			# Delete the pv
			kubectl delete pv $pv_obj 2> /dev/null
		fi
	done
	# Delete the pipeline along with its tasks 
	kubectl delete pipeline $p_obj 2> /dev/null
	for t in "${t_objs[@]}"; do
		kubectl delete task $t 2> /dev/null
	done	
	# Delete pipeline and tasks temp yaml file
	rm files/pipeline.yaml
done
