BEGIN {
  FS="\t"
}

{ 
	#print $13
	if( $13 == "NA" )
  	{count_na += 1} 
}

END {
  printf("%d",count_na)
  printf("\n")
}

#Usage : cat B06_qry/* |awk -f count.awk

#cat B06_raw/*20100610* |awk 'BEGIN{FS="\t"} {if($8 == 2) print $11}' > dscore1_0610.txt

#cat /cygdrive/d/B06/B06_IdealSet_July02.txt |awk 'BEGIN{FS="\t"} {if(NF == 7) print $0}' > /cygdrive/d/B06/B06_IdealSet_July02

#cat B06_raw/* |awk 'BEGIN{FS="\t"} {if($13 == "NA") print $3}' > hrs_na.txt

#cat B06_raw/* |awk 'BEGIN{FS="\t"} {if($14 == "NA") print $3,"\t",$9}' >hrs_na.txt

