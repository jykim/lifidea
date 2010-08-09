BEGIN {
  FS="\t"
}

{
  for (i=12; i<=NF; i++) { 
	if($i == -1) sum[i] += 1 
	else if( NR == 1 ) printf("%s\t", $i)
  } 
}

END {
  #printf("%d,",NR)
  for (i=12; i<=NF; i++ ) 
    { printf("%.7f\t", sum[i]/NR) }
  printf("\n")
}
