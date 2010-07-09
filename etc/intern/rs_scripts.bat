.\bin\ExtractColumnsFromTSV.exe FeatureValuesPerQueryPerDocument-1-18-28-04.2924031.tsv
.\bin\ExtractColumnsFromTSV.exe FeatureValuesPerQueryPerDocument-1-06-25-27.7020138.tsv
.\bin\ExtractColumnsFromTSV.exe FeatureValuesPerQueryPerDocument-1-07-15-10.7886414.tsv
.\bin\ExtractColumnsFromTSV.exe EnUsB06-FeatureValuesPerQueryPerDocument-1-2010-Jun-07-11-53-49.tsv

# Re-process all the data 
.\bin\ExtractColumnsFromTSV.exe EnUsB06-FeatureValuesPerQueryPerDocument-1-2010-Jun-10-04-46-55.tsv EnUsB06-FeatureValuesPerQueryPerDocument-1-2010-Jun-11-11-15-29.tsv EnUsB06-FeatureValuesPerQueryPerDocument-1-2010-Jun-12-11-59-22.tsv EnUsB06-FeatureValuesPerQueryPerDocument-1-2010-Jun-13-11-52-17.tsv 
.\bin\ExtractColumnsFromTSV.exe EnUsB06-FeatureValuesPerQueryPerDocument-1-2010-Jun-14-02-23-11.tsv EnUsB06-FeatureValuesPerQueryPerDocument-1-2010-Jun-15-11-22-41.tsv EnUsB06-FeatureValuesPerQueryPerDocument-1-2010-Jun-16-10-37-24.tsv EnUsB06-FeatureValuesPerQueryPerDocument-1-2010-Jun-17-10-18-53.tsv 
.\bin\ExtractColumnsFromTSV.exe EnUsB06-FeatureValuesPerQueryPerDocument-1-2010-Jun-18-11-19-56.tsv EnUsB06-FeatureValuesPerQueryPerDocument-1-2010-Jun-19-10-39-25.tsv EnUsB06-FeatureValuesPerQueryPerDocument-1-2010-Jun-20-10-12-33.tsv EnUsB06-FeatureValuesPerQueryPerDocument-1-2010-Jun-21-10-44-22.tsv
.\bin\ExtractColumnsFromTSV.exe EnUsB06-FeatureValuesPerQueryPerDocument-1-2010-Jun-22-01-18-59.tsv EnUsB06-FeatureValuesPerQueryPerDocument-1-2010-Jun-23-10-47-06.tsv EnUsB06-FeatureValuesPerQueryPerDocument-1-2010-Jun-24-11-35-20.tsv
.\bin\ExtractColumnsFromTSV.exe EnUsB06-FeatureValuesPerQueryPerDocument-1-2010-Jun-25-10-48-43.tsv EnUsB06-FeatureValuesPerQueryPerDocument-1-2010-Jun-26-10-41-07.tsv EnUsB06-FeatureValuesPerQueryPerDocument-1-2010-Jun-27-10-29-47.tsv
.\bin\ExtractColumnsFromTSV.exe EnUsB06-FeatureValuesPerQueryPerDocument-1-2010-Jun-28-10-19-31.tsv EnUsB06-FeatureValuesPerQueryPerDocument-1-2010-Jun-29-10-27-44.tsv EnUsB06-FeatureValuesPerQueryPerDocument-1-2010-Jun-30-11-20-49.tsv
.\bin\ExtractColumnsFromTSV.exe EnUsB06-FeatureValuesPerQueryPerDocument-1-2010-Jul-01-10-40-27.tsv EnUsB06-FeatureValuesPerQueryPerDocument-1-2010-Jul-02-10-19-59.tsv EnUsB06-FeatureValuesPerQueryPerDocument-1-2010-Jul-03-10-46-33.tsv
.\bin\ExtractColumnsFromTSV.exe EnUsB06-FeatureValuesPerQueryPerDocument-1-2010-Jul-04-10-42-16.tsv EnUsB06-FeatureValuesPerQueryPerDocument-1-2010-Jul-05-10-24-14.tsv EnUsB06-FeatureValuesPerQueryPerDocument-1-2010-Jul-06-10-12-31.tsv
.\bin\ExtractColumnsFromTSV.exe EnUsB06-FeatureValuesPerQueryPerDocument-1-2010-Jul-07-10-18-18.tsv EnUsB06-FeatureValuesPerQueryPerDocument-1-2010-Jul-08-10-26-45.tsv
ruby -I /cygdrive/c/dev/lifidea/rubylib/ code\rs_process.rb

# Create single big result file
export batch=test
grep -h ^[0-9] B06_$batch/result_daily_15* > result_daily_$batch.tmp 
cat result_daily_header.tsv result_daily_$batch.tmp > result_daily_$batch.txt 
cat result_all_header.tsv B06_$batch/result_all_15* > result_all_$batch.txt 
cat result_docs_header.tsv B06_$batch/result_docs_15* > result_docs_$batch.txt 
#finally, change the format of result_docs_$batch.txt in excel


# Count NA judgments
cat B06_raw/*20100610*|awk -f count_na.awk
cat B06_raw/*20100611*|awk -f count_na.awk
cat B06_raw/*20100612*|awk -f count_na.awk
cat B06_raw/*20100613*|awk -f count_na.awk
cat B06_raw/*20100614*|awk -f count_na.awk
cat B06_raw/*20100615*|awk -f count_na.awk
cat B06_raw/*20100616*|awk -f count_na.awk
cat B06_raw/*20100617*|awk -f count_na.awk
cat B06_raw/*20100618*|awk -f count_na.awk
cat B06_raw/*20100619*|awk -f count_na.awk

.\TestQueryStability.exe "itchy virginia" http://www.funadvice.com/q/why_is_it_11806 

.\TestQueryStability.exe "itchy virginia" http://www.womenanswers.org/womenshealth/3231-women-health-4.html

.\TestQueryStability.exe "itchy virginia" http://www.steadyhealth.com/Red__Itchy_Vigina_t138898.html

.\TestQueryStability.exe "ukulele tabs for white horse" http://www.youtube.com/watch?v=Z3_dyhEKtYU&feature=related
