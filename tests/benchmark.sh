#!/bin/bash

# Number of overall iterations
NUM_ITS=100

# Set the type of benchmark to run (one at a time)
LOCAL_MEM=0
LOCAL_VOL_FULL=0
LOCAL_VOL_FULL_MOPS=0
LOCAL_RNOBUFF=0
REMOTE_NFS_FULL=0
REMOTE_NFS_FULL_SAMENODE=0
REMOTE_NFS_FULL_MOPS=0
REMOTE_NFS_RNOBUFF=0

# Set the dimensions to benchmark
dims=( "1 KB"
	"4 KB" 
	"16 KB" 
	"64 KB" 
	"256 KB" 
	"1 MB"
	"4 MB" 
	"16 MB"
	"64 MB"
	"256 MB"
    "1 GB"
)	

# Global variables
num_bytes=0
pipeline_yaml_path=""
rtimes_folder=""
wtimes_folder=""

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

# Check if a configuration is given
if [ $((LOCAL_MEM + LOCAL_VOL_FULL + LOCAL_VOL_FULL_MOPS + LOCAL_RNOBUFF + REMOTE_NFS_FULL + REMOTE_NFS_FULL_SAMENODE + REMOTE_NFS_FULL_MOPS + REMOTE_NFS_RNOBUFF )) -eq 0 ]
then 
    echo "ERROR: You have to provide a configuration to benchmark!"
    exit 1

elif [ $((LOCAL_MEM + LOCAL_VOL_FULL + LOCAL_VOL_FULL_MOPS + LOCAL_RNOBUFF + REMOTE_NFS_FULL + REMOTE_NFS_FULL_SAMENODE + REMOTE_NFS_FULL_MOPS + REMOTE_NFS_RNOBUFF )) -gt 1 ]
then
	echo "ERROR: You can run one configuration tests per time!"
	exit 1
fi

# Set the file names
if [[ $LOCAL_MEM == 1 ]]
then
	pipeline_yaml_path="files/py_rw_ops_mem_bench_pipeline_tasks.yaml"
	rtimes_folder="times/py/local_mem_vol/read/"
	wtimes_folder="times/py/local_mem_vol/write/"
elif [[ $LOCAL_RNOBUFF == 1 || $REMOTE_NFS_RNOBUFF == 1 ]]
then
	pipeline_yaml_path="files/py_r_rnobuff_op_bench_pipeline_task.yaml"
	if [[ $LOCAL_RNOBUFF = 1 ]]
	then
		rtimes_folder="times/py/local_vol_rnobuff/read/"
	else
		rtimes_folder="times/py/remote_nfs_vol_rnobuff/read/"
	fi
elif [[ $LOCAL_VOL_FULL == 1 ]]
then
	pipeline_yaml_path="files/py_rw_ops_full_bench_pipeline_tasks.yaml"
	rtimes_folder="times/py/local_vol_full/read/"
	wtimes_folder="times/py/local_vol_full/write/"
elif [[ $LOCAL_VOL_FULL_MOPS == 1 ]]
then
	pipeline_yaml_path="files/py_multiple_rw_ops_full_bench_pipeline_tasks.yaml"
	rtimes_folder="times/py/local_vol_full_mops/read/"
	wtimes_folder="times/py/local_vol_full_mops/write/"
elif [[ $REMOTE_NFS_FULL == 1 ]]
then
	pipeline_yaml_path="files/py_rw_ops_full_bench_pipeline_tasks.yaml"
	rtimes_folder="times/py/remote_nfs_vol_full/read/"
	wtimes_folder="times/py/remote_nfs_vol_full/write/"
elif [[ $REMOTE_NFS_FULL_SAMENODE = 1 ]]
then
	pipeline_yaml_path="files/py_rw_ops_full_bench_pipeline_tasks.yaml"
	rtimes_folder="times/py/remote_nfs_vol_full_samenode/read/"
	wtimes_folder="times/py/remote_nfs_vol_full_samenode/write/"
elif [[ $REMOTE_NFS_FULL_MOPS == 1 ]]
then
	pipeline_yaml_path="files/py_multiple_rw_ops_full_bench_pipeline_tasks.yaml"
	rtimes_folder="times/py/remote_nfs_vol_full_mul/read/"
	wtimes_folder="times/py/remote_nfs_vol_full_mul/write/"
fi

# Create output folders
mkdir -p $rtimes_folder
if [[ $LOCAL_RNOBUFF == 0 && $REMOTE_NFS_RNOBUFF == 0 ]]
then
	mkdir -p $wtimes_folder
fi

exec 5>&1

# Set pv and pipelinerun files
pv_yaml=""
plr_yaml=""
if [[ $LOCAL_MEM == 1 ]]
then
	plr_yaml="files/pipelinerunEmptyDir.yaml"
elif [[ $LOCAL_VOL_FULL == 1 || $LOCAL_VOL_FULL_MOPS == 1 || $LOCAL_RNOBUFF == 1 ]]
then	
	pv_yaml="../storage_objs/persistentVolumeTektonVol.yaml"
	plr_yaml="files/pipelinerun.yaml"
elif [[ $REMOTE_NFS_FULL == 1 || $REMOTE_NFS_FULL_SAMENODE == 1 || $REMOTE_NFS_FULL_MOPS == 1 || $REMOTE_NFS_RNOBUFF == 1 ]]
then
	pv_yaml="../storage_objs/persistentVolumeTektonNFS.yaml"
	if [[ $REMOTE_NFS_RNOBUFF == 1 ]]
	then
		plr_yaml="files/pipelinerunNFSrnobuff.yaml"	
	elif [[ $REMOTE_NFS_FULL_SAMENODE == 1 ]]
	then
		plr_yaml="files/pipelinerunNFSSameNode.yaml"
	else
		plr_yaml="files/pipelinerunNFS.yaml"
	fi
fi

# Run the tests
for i in "${dims[@]}"; do
	if [[ $LOCAL_MEM == 1 ]]
	then
		echo "**************************** LOCAL MEM BENCHMARK ON $i ****************************"
	elif [[ $LOCAL_VOL_FULL == 1 ]]
	then 
		echo "**************************** LOCAL VOL FULL BENCHMARK ON $i ****************************"
	elif [[ $LOCAL_VOL_FULL_MOPS == 1 ]]
	then
		echo "**************************** LOCAL VOL FULL MOPS BENCHMARK ON $i ****************************"
	elif [[ $LOCAL_RNOBUFF == 1 ]]
    then 
		echo "**************************** LOCAL NO CACHE BENCHMARK ON $i ***********************"
    elif [[ $REMOTE_NFS_FULL == 1 ]]
	then
		echo "**************************** REMOTE NFS FULL BENCHMARK ON $i *******************************"
	elif [[ $REMOTE_NFS_FULL_MOPS == 1 ]]
	then
		echo "**************************** REMOTE NFS FULL MOPS BENCHMARK ON $i *******************************"
	elif [[ $REMOTE_NFS_RNOBUFF == 1 ]]
	then 
		echo "**************************** REMOTE NFS NOCACHE BUFF BENCHMARK ON $i *******************************"
	elif [[ $REMOTE_NFS_FULL_SAMENODE == 1 ]]
	then
		echo "**************************** REMOTE NFS FULL SAMENODE BENCHMARK ON $i *******************************"
	fi
	
    # Modifiy the pipeline tasks with the proper dimension
	cp $pipeline_yaml_path files/pipeline.yaml
	if [[ $LOCAL_RNOBUFF == 0 && $REMOTE_NFS_RNOBUFF == 0 ]]
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
	read_fpath="${rtimes_folder}${filename}"
	if [[ $LOCAL_RNOBUFF == 0 && $REMOTE_NFS_RNOBUFF == 0 ]]
	then
		if [[ $REMOTE_NFS_FULL_MOPS == 1 || $LOCAL_VOL_FULL_MOPS == 1 ]]
		then
			first_filename="${dim_nospace}_first_times.txt"
			others_filename="${dim_nospace}_others_times.txt"
			read_first_fpath="${rtimes_folder}${first_filename}"
			read_others_fpath="${rtimes_folder}${others_filename}"	
			write_first_fpath="${wtimes_folder}${first_filename}"
			write_others_fpath="${wtimes_folder}${others_filename}"
		else
			write_fpath="${wtimes_folder}${filename}"
		fi
	fi
	
	# Run multiple times to get a fair r/w througput value
	for (( j=1; j<=$NUM_ITS; ++j)); do
		echo "RUNNING $j/$NUM_ITS ITERATION.."
		# Clean remote folder before computing 
		if [[ $REMOTE_NFS_FULL == 1 || $REMOTE_NFS_FULL_MOPS == 1 ]]
		then
			sudo ssh root@10.0.26.218 'rm /home/vagrant/kubedata/benchmark/*'
		fi
		if [[ $LOCAL_VOL_FULL_MOPS == 1 ]]
		then
			sudo ssh root@10.0.26.216 'rm -rf /mnt/disk/vol2/benchmark/*'
		fi
		if [[ $LOCAL_MEM == 0 ]]
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
				exit 1
			fi	
			out=$(kubectl get pipelineruns 2> /dev/null)
			set -- $out
		done	
		echo "Pipeline has finished!"
		tkn pipelinerun logs $prun_obj > out.log
		times=$(grep -hnr "seconds" out.log |  awk '{print $5}')
		rm out.log
		echo "Writing times on output files.."
		if [[ $REMOTE_NFS_FULL_MOPS == 0 && $LOCAL_VOL_FULL_MOPS == 0 ]]
		then 
			if [[ $LOCAL_RNOBUFF == 0 && $REMOTE_NFS_RNOBUFF == 0 ]]
			then
				echo $times | awk '{print $1}' >> $write_fpath
				echo $times | awk '{print $2}' >> $read_fpath 
			else
				echo $times >> $read_fpath
			fi
		else
			counter=1
			array_times=($times)
			for k in "${array_times[@]}"
			do
				if (( $counter % 100 == 1 ))
				then
					if [[ $counter -le 100 ]]
					then
						echo $k >> $write_first_fpath
					else
						echo $k >> $read_first_fpath
					fi
				else
					if [[ $counter -le 100 ]]
					then
						echo $k >> $write_others_fpath
					else
						echo $k >> $read_others_fpath
					fi
				fi
				counter=$((counter+1))
			done
		fi
		# Delete the pipelinerun
		kubectl delete pipelinerun $prun_obj 2> /dev/null
		# Delete the pv
		if [[ $LOCAL_MEM == 0 ]]
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
