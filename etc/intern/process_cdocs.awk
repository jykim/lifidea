BEGIN {
  FS="\t"
}

{
  for (i=1; i<=NF; i++) {
	if(i != 4 && i != 13) printf("%s\t", $i)
  }
  printf("%s\n",$13)
}

#cat filename |awk 'BEGIN{FS="\t"} {print $4,"\t",$3,"\t",$1,"\t",$(NF)}'