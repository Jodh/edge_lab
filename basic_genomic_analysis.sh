#! /usr/bin/bash

# todo
# add logic for getting variable values - done
# add logic for paired end sra runs and single runs - done
# long term: add directory structure
# long term: add support for automatically opening the html quality control files

# define variables
link_reference_genome="somelink"
reference_genome="somefile"
sra_run_list="path/to/file.txt"
pair_ended="y"
sra_list=""

#get inputs
echo "This script will download and run basic genome analysis in the directory it is called. Make sure you have enough space for the reference genome and associated sra accessions in the current directory."
read -p "Enter or paste reference genome link from ncbi " link_reference_genome
read -p "Enter the name you want the reference genome to be called, example: GCF_00001, human_reference_genome " reference_genome
read -p "Enter path to sra_run file or sra accessions. The file should contain a list of unique identifiers. Make sure that each SRA iD is either pair-ended or single read. Do not mix the two types. " sra_run_list
read -p "Press [y] if all SRA accessions in the list are pair ended, press [n] otherwise. " pair_ended
read -p "Enter number of threads to use for the mapping process, press enter if unsure. " n_of_threads
n_of_threads=${n_of_threads:-4}

# download reference genome -> reference_genome
# todo: add logic to see if files are already present before downloading reference genome and sra fastq files
wget -O $reference_genome $link_reference_genome

# download SRA runs to map -> .fastq files
while read -r sra
do
	fastq-dump --split-3 $sra
done < $sra_run_list

# generate quality checks for sra runs -> html files and a zip file
if [ $pair_ended = "y" ]; then
	while read -r sra
	do
		sra_list="${sra_list}${sra}_1.fastq ${sra}_2.fastq "
		fastqc --svg $sra_list
	done < $sra_run_list
else
	while read-r sra
	do
		sra_list="${sra_list}${sra}.fastq "
		fastqc --svg $sra_list
	done < $sra_run_list
fi
#echo "$sra_list"

# index reference genome -> indexed_genome file
indexed_genome="indexed_${reference_genome}"
bwa-mem2 index -p $indexed_genome $reference_genome

# map sra runs on the indexed genome -> .sam file(s)

if [ $pair_ended = "y" ]; then
	while read -r sra
		do
			file1="${sra}_1.fastq"
			file2="${sra}_2.fastq"
			output="${sra}.sam"
			bwa-mem2 mem -t $n_of_threads $indexed_genome $file1 $file2 -o $output
		done < $sra_run_list
else
	while read -r sra
		do
			file1="${sra}.fastq"
			output="${sra}.sam"
			bwa-mem2 mem -t $n_of_threads $indexed_genome $file1 -o $output
		done < $sra_run_list
fi

# convert to binary assembly file -> .bam file

while read -r sra
	do
		samtools view -@ $n_of_threads -b -o "${sra}.bam" "${sra}.sam"
	done < $sra_run_list

# sort the bam file -> sorted .bam file
while read -r sra
	do
		samtools sort -O bam -o "sorted_${sra}.bam" "${sra}.bam"
	done < $sra_run_list

# index the sorted bam file -> indexed .bam file
while read -r sra
	do
		samtools index "sorted_${sra}.bam"
	done < $sra_run_list


