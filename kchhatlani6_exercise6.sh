#!/bin/bash
 realign=0
 index=0
 gunzip=0
 snp=1
while getopts "a:b:r:e:f:i:o:vz:h" option
do
	case $option in 
		a) reads1=$OPTARG;;
		b) reads2=$OPTARG;;
		r) ref=$OPTARG;;
		e) realign=$OPTARG;;
		f) millsFile=$OPTARG;;
		i) index=$OPTARG;;
		o) output=$OPTARG;;
		z) gunzip=$OPTARG;;
		v) verbose=1;;
		h) echo "Give 2 reads in -a and -b respectively, 1 genome reference file in -r and 1 Mills File in -f. Give the name of the vcf file without extension in -o. Give 1 if you want to perform realignment else give 0 in -e. Give 1 if you want to index your realigned file else give 0 in -i. Give 1 if you want to gunzip the vcf.gz file else give 0 in -z. Give -v if you want to know what steps are happening ";;
	esac
done

#TAKING INPUTS and FILE CHECKING
if [[ $verbose -eq 1 ]]
then
	echo "Checking if both Input reads file – pair 1 and pair 2 exist"
fi

if [[ -f $reads1 ]]
then
	echo "Input reads file – pair 1 exists"
else echo "Input reads file – pair 1 does not exist."
fi

if [[ -f $reads2 ]]
then
	echo "Input reads file – pair 2 exists"
else echo "Input reads file – pair 2 does not exist."
fi

#MAPPING
if [[ $verbose -eq 1 ]]
then
	echo "Indexing the reference genome file --> mapping both the reads to reference genome --> Sorting the bam file --> indexing the bam file for GATK"
fi

if [[ -f $ref ]]
then
	#Indexing the reference genome file
	mkdir reference
	if [[ $verbose -eq 1 ]] 
	then
		echo "Indexing the reference genome file"
	fi
	bwa index $ref 
	#Mapping reads1 and reads2 to reference genome
	if [[ $verbose -eq 1 ]]
	then
	echo "Mapping reads to the reference" 
	fi
	bwa mem -R '@RG\tID:foo\tSM:bar\tLB:library1' $ref $reads1 $reads2 > lane.sam
	#Cleaning up unusual information left by BWA (Conversion of sam to bam)
	if [[ $verbose -eq 1 ]]
	then
	echo "Making lane_fixmate.bam" 
	fi
	samtools fixmate -O bam lane.sam lane_fixmate.bam
	#Sorting the bam file for GATK
	if [[ $verbose -eq 1 ]]
	then
	echo "Making tmp directory" 
	fi
	mkdir tmp
	cd tmp
	mkdir lane_temp
	cd

	if [[ $verbose -eq 1 ]]
	then
	echo "Making lane_sorted.bam" 
	fi
	samtools sort -O bam -o lane_sorted.bam -T ~/tmp/lane_temp lane_fixmate.bam
	if [[ $verbose -eq 1 ]]
	then
	echo "Indexing lane_sorted.bam" 
	fi
	samtools index lane_sorted.bam
else echo "Reference genome file does not exist. Please enter .fa files only"
fi

#GATK needs a .fai file
samtools faidx $ref 
#GATK needs a .dict file
#can change the dict name according to the chromosome number we want
samtools dict $ref -o chr17.dict

#REALIGN
if [[ $verbose -eq 1 ]]
then
	echo "Realignment Begins"
fi

if [[ $verbose -eq 1 ]]
then
	echo "RealignerTargetCreator step and IndelRealigner step" 
fi

#RealignerTargetCreator Requires Java 8.0.301 version
#Add the path of java 0.0.301 while running
#For eg:- /home/kirti/Downloads/jre-8u301-linux-x64/jre1.8.0_301/bin/java -Xmx2g -jar ~/GenomeAnalysisTK.jar .....
if [[ $realign -eq 1 ]]
then
	java -Xmx2g -jar ~/GenomeAnalysisTK.jar -T RealignerTargetCreator -R $ref -I ~/lane_sorted.bam -o lane.intervals -known $millsFile
	java -Xmx4g -jar ~/GenomeAnalysisTK.jar -T IndelRealigner -R $ref -I ~/lane_sorted.bam -targetIntervals lane.intervals -known $millsFile -o lane_realigned.bam
fi

if [[ $verbose -eq 1  ]]
then
	echo "Indexing the realigned bam file"
fi

#INDEX BAM
if [[ $index -eq 1 ]]
then
samtools index ~/lane_realigned.bam
fi

#VARIANT CALLING
if [[ $verbose -eq 1 ]]
then
	echo "Variant calling Begins"
fi
if [[ -f $output.vcf ]]; then
	echo "vcf file already exists. Enter 1 to overwrite it or 0 to exit the program?"
	read snp
fi

if [[ $snp -eq 1 ]]
then 
bcftools mpileup -Ou -f $ref ~/lane_realigned.bam | bcftools call -vmO z -o $output.vcf.gz
else exit
fi


if [[ $verbose -eq 1 ]]
then
	echo "Your vcf file is ready" 
fi

if [[ $gunzip -eq 1 ]]
then
	gunzip $output.vcf.gz
fi

if [[ $gunzip -eq 1 ]]
then
	echo "Your vcf file is gunzipped" 
fi


