BEGIN {
  FS=","
}

{  
  for (i=3; i<=NF; i++) { sum[i]+= $i } 
}

END {
  printf("%d,",NR)
  for (i=3; i<=NF; i++ ) 
    { printf("%.4f,", sum[i]/NR) }
  printf("\n")
}