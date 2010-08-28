BEGIN {
  FS="\t"
}

{ 
	#print $13
	if( $10 == "1" && $16 == "NA" ){count_na1 += 1} 
	if( $10 == "2" && $16 == "NA" ){count_na2 += 1} 
	if( $10 == "3" && $16 == "NA" ){count_na3 += 1} 
	if( $10 == "4" && $16 == "NA" ){count_na4 += 1} 
	if( $10 == "5" && $16 == "NA" ){count_na5 += 1} 
	if( $16 == "NA" ){count_na += 1} 
	}

END {
  printf("%d\n",count_na1)
  printf("%d\n",count_na2)
  printf("%d\n",count_na3)
  printf("%d\n",count_na4)
  printf("%d\n",count_na5)
  printf("%d\n",count_na)
}

#Usage : cat B06_raw_all/* |awk -f code/count_na.awk

#cat B06_raw/*20100610* |awk 'BEGIN{FS="\t"} {if($8 == 2) print $11}' > dscore1_0610.txt

#cat /cygdrive/d/B06/B06_IdealSet_July02.txt |awk 'BEGIN{FS="\t"} {if(NF == 7) print $0}' > /cygdrive/d/B06/B06_IdealSet_July02

#cat B06_raw/* |awk 'BEGIN{FS="\t"} {if($13 == "NA") print $3}' > hrs_na.txt

#cat B06_raw/* |awk 'BEGIN{FS="\t"} {if($14 == "NA") print $3,"\t",$9}' >hrs_na.txt

