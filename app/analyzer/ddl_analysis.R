setwd("/Users/lifidea/dev/rails/ddl")
ddl = read.table("stat_day_2009-06-05_2009-06-14.txt",header=T)
#r_lm = lm(ddl$grade_day ~ ddl$count_day_cal + ddl$count_day_web + ddl$count_day_todo + ddl$diff_time_day_cal + ddl$min_time_day_app)
r_lm = lm(ddl$grade_day ~ ddl$count_day_cal + ddl$diff_time_day_cal + ddl$min_time_day_app)
summary(r_lm)

