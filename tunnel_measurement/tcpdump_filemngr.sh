ine_name=$1
#Checks for any new tcpdump file
#and saves it in /anfs/nos2/cr409/signpost_data/
mkdir ~/sgpost_tcpdumpOutput/
while true 
do
#copy to cr409@slogin:/anfs/nos2/cr409/signpost_data
#remove copied files
   for f in ~/sgpost_tcpdumpOutput/*pcap*;
   do
      if [[ "$f" == "`ls ~/sgpost_tcpdumpOutput/*.pcap -t1 | head -n1`" ]]
          then echo "Newest file, not transmitting";
      else
          echo "Transfering $f";
          name="`basename $f`"
          ssh -i ~/.ssh/signpost-to-lab aa535@ramsey.cl.cam.ac.uk mkdir /anfs/nos2/aa535/signpost_data/$machine_name
          scp -i ~/.ssh/signpost-to-lab $f aa535@ramsey.cl.cam.ac.uk:/anfs/nos2/aa535/signpost_data/$machine_name/$name
          rm $f
      fi

   done
   sleep 10
done


