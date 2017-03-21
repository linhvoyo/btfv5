#!/bin/bash

#btfv3
#fixed sorting error by using "sort -V -k1,1 -t " "  --stable --parallel=10 -T ./temp -S 10G"
#ex. HWUSI­EAS1680_10:3:10:11057:206422 and HWUSI­EAS1680_10:3:101:1057:206422. The btfv2 uses "sort  -k1,1 -t " "  --stable --parallel=10 -T ./temp -S 10G" command which ignores ":". As a result, the example headers are sorted based on the sequences instead of ID names. 
#Moved results.txt file generated from bam validate to the log file.
#Prints out docker version in log file

#btfv4 
#can take in .cram 

#btfv5 
#fastqCombinePairedEnd before Dedup



bamInput=$input

#making temp dir.
mkdir $bamInput'_'output



#bam validate
if $(echo $input | grep -q .bam ) ; then
  echo `date` "Bam validate" >> $bamInput.log
  bam validate --in $bamInput 2>>$bamInput.log
  printf "\n" >>$bamInput.log
  printf "%*s" $COLUMNS | tr " " "=" >>$bamInput.log
  printf "\n" >>$bamInput.log
else
  echo `date` "Bam validate" >> $bamInput.log
  echo -e "\t\t\t\t $bamInput: Bam validate step skipped since input file is cram???">>$bamInput.log
fi;

set -eu -o pipefail
#set -eu here because the bam validate part will return a non zero value then crahs

#samtools
echo `date` "Samtools fastq conversion">>$bamInput.log
echo -e " \t\t\t\t $bamInput " >>$bamInput.log
samtools fastq -1 ./$bamInput'_'output/${bamInput}.R1.fq -2 ./$bamInput'_'output/${bamInput}.R2.fq $bamInput

#fastqCombinePairedEnd
a=./$bamInput'_'output/$bamInput.R1.fq
b=./$bamInput'_'output/$bamInput.R2.fq
size=$(wc -c < $b)
if [ $size -ge 10 ]; then
echo `date` "Combining paired end reads" >>$bamInput.log
echo -e "\t\t\t\t $bamInput: is paired end reads">>$bamInput.log
python /root/scripts/fastqCombinePairedEnd.py $a $b
else
echo -e "\t\t\t\t $bamInput: is single end reads">>$bamInput.log
mv ./$bamInput'_'output/${bamInput}.R1.fq ./$bamInput'_'output/${bamInput}.R1.fq.perl_pairs_R1.fastq
fi

#dedup
echo `date` "Removing duplicate read ids - $bamInput">>$bamInput.log
for j in {1..2}; do
cat ./$bamInput'_'output/${bamInput}.R${j}.fq_pairs_R${j}.fastq | perl /root/scripts/mergelines.pl | sort -V -k1,1 -t " "  --stable --parallel=10 -T ./ -S 10G | uniq | perl /root/scripts/splitlines.pl > ./$bamInput'_'output/${bamInput}.R${j}.fastq ;
done


#pigz
for uncompressedFq in ./$bamInput'_'output/*${bamInput}.R[0-9].fastq;do
  echo `date` "Compressing file $uncompressedFq">>$bamInput.log; pigz $uncompressedFq;
done

#rename
for compressedFq in ./$bamInput'_'output/*fastq.gz;do
  mv $compressedFq $(echo ${compressedFq/.perl_pairs_R[0-9].fastq.gz}| sed 's/\(.*\)..[b,cr]am/\1/')
done

echo `date` "$bamInput - Conversion done using linhvoyo/btfv5 docker "  >>$bamInput.log

#moving gz. files to work directory
for gz in ./$bamInput'_'output/*.gz; do mv $gz ./; done

#
rm -r $bamInput'_'output

#chown output files
finish() {
    # Fix ownership of output files
    uid=$(stat -c '%u:%g' /data)
    chown $uid $( echo /data/*${bamInput}.R[0-9].fastq.gz | sed 's/..[b,cr]am//')
    chown $uid /data/$bamInput.log
}
trap finish EXIT



