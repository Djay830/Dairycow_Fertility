data master1;
set master1;
P_HF=(friesian_breed_16ths/16);
P_J=(jersey_breed_16ths/16);
P_HF_S=(sire_friesian_breed_16ths/16);
P_J_S=(sire_jersey_breed_16ths/16);
P_HF_D=(dam_friesian_breed_16ths/16);
P_J_D=(dam_jersey_breed_16ths/16);
hfxj=((P_HF_S*P_J_D)+(P_J_S*P_HF_D));
run;quit;

data master1;
set master1;
psc=ffr_mating_start_date_key+282;
run;quit;

proc sql;
alter table master1
  modify psc format=DDMMYY10.;
quit;

data master1 (drop=calving_ssn_day_new);
set master1;
run;quit;

data master1;
set master1;
calving_ssn_day=datdif(psc,nextssn_calving,'Actual');
*if calving_ssn_day>=0 then calving_ssn_day_new=calving_ssn_day+1;
run;quit;

*CR21;
data master1;
set master1;
if calving_ssn_day=. then CR21=.;
else if calving_ssn_day<21 then CR21=1;
else CR21=0;
run;

*CR42;
data master1;
set master1;
if calving_ssn_day=. then CR42=.;
else if calving_ssn_day<42 then CR42=1;
else CR42=0;
run;

proc means data=master1;
var CR21 CR42;
class herd_name;
where season_year^=2021;
run;quit;

data master1;
set master1;
if mating1>0 and ffr_mating_end_date_key<mating1 then outlier_mating=1;*162;
if mating1>0 and mating1<ffr_mating_start_date_key then outlier_mating=1;
run;quit;

*162;
proc means data=master1;
var outlier_mating;
run;


*Trait calculation;
data master1;
set master1;
SMFS=datdif(ffr_mating_start_date_key,mating1,'Actual');
CFS=datdif(calving_date,mating1,'Actual');
CI=datdif(calving_date,nextssn_calving,'Actual');
Mating_length= datdif(ffr_mating_start_date_key,ffr_mating_end_date_key,'Actual');
if ffr_mating_end_date_key<mating1 then SMFS='.';
if mating1<ffr_mating_start_date_key then SMFS='.';
if mating1<calving_date then CFS='.';
if ffr_mating_end_date_key<mating1 then CFS='.';
if mating1>0 and CFS<7 then outlier_CFS=1;*0;
run;

proc means data=master1;
var SMFS CFS CI Mating_length outlier_CFS;*0;
run;

*SR21;
data master1;
set master1;
if SMFS=. then SR21=0;
else if SMFS<0 then SR21=0;
else if 0<=SMFS<21 then SR21=1;
else SR21=0;
run;

*SR42;
data master1;
set master1;
if SMFS=. then SR42=0;
else if SMFS<0 then SR42=0;
else if 0<=SMFS<42 then SR42=1;
else SR42=0;
run;

*DMCD;
Proc sql;
create table dmcd as
select owner_ptpt_code, calving_date,season_year,lic_animal_key,
 min(calving_date) as start_calving format=DDMMYY10.,
 median(calving_date)as median_calving format=DDMMYY10.,
 max(calving_date) as end_calving format=DDMMYY10.
from D1d4_calving
group by owner_ptpt_code,season_year
order by owner_ptpt_code, lic_animal_key;
run;quit;

*combine dmcd;
proc sql;
 create table master1 as
    select distinct x.*, y. median_calving
    from master1 x left join dmcd y
    on (x.lic_animal_key=y.lic_animal_key) and (x.calving_date=y.calving_date) and (x.season_year=y.season_year)
    order by lic_animal_key, season_year;
run; quit;

data master1;
set master1;
AC=datdif(birth_date,calving_date,'Actual');
ACY= round(AC/365.25, 0.01);
dmcd=datdif(calving_date,median_calving,'Actual');
run;

proc sgplot data=master1;
   histogram AC;
   title 'Histrogram of AC';
   where lactation_number=1;
   run;

proc sgplot data=master1;
   histogram ACY;
   title 'Histrogram of AC in years';
    where lactation_number=2 and ACY<4;
   run; 

*Cows left the herd prior to the end of mating date, but some cows had the mating records(68 had mating 1);
data master1;
set master1;
if last_HT_date<ffr_mating_end_date_key and PD_date1=. and nextssn_calving=. then Left_before_Mating_enddate=1;
run;quit;

*327 cows were left the herd before mating end dates;
proc freq data=master1;
tables Left_before_Mating_enddate;
run;quit;

*Left before mating end date without no any mating records;
data master1;
set master1;
if last_HT_date<ffr_mating_end_date_key and mating1=. and  PD_date1=. and nextssn_calving=. then Left_MED_no_matings=1;
run;quit;

*260 cows had no mating, no PD, no subsequent calvings and had last herd test milk record before mating end date;
proc freq data=master1;
tables Left_before_Mating_enddate Left_MED_no_matings;
run;quit;

*data master1 (drop=Left_before_Mating_enddate);
set master1;
run;quit;

data master1;
set master1;
if last_PD_count>0 and last_PD_count<35 then outlier_PD=1;
if last_PD_count>0 and last_PD_count>122 then outlier_PD=1;
run;quit;

*64;
proc freq data=master1;
tables outlier_PD;
run;quit;

data master1;
set master1;
if last_PD_status= 'pregnant' and 34<last_PD_count<123 and nextssn_calving>0 then pregnancy='pregnant';
else if last_PD_status= 'pregnant' and 34<last_PD_count<123 then pregnancy='pregnant';
else if nextssn_calving>0 then pregnancy='pregnant';
else if last_PD_status='empty - not pregnant'  and last_PD_count=. and nextssn_calving=. then pregnancy='empty';
else if last_PD_status='doubtful' and last_PD_count=. and nextssn_calving=. then pregnancy='empty';
else if last_PD_date=. and last_PD_status=. and last_PD_count=. and nextssn_calving=. then pregnancy='empty';
run;

proc freq data=master1; *pregnant 5776, empty 1123, freq missing 32;
tables pregnancy;
run;

data master1;
set master1;
if pregnancy='pregnant' then conception_date=last_PD_date-last_PD_count;*aged pregnancies with or without calvings in next season;
if nextssn_calving>0 and last_PD_count=. then conception_date=nextssn_calving-282;*non_aged pregnancies;
if nextssn_calving>0 and outlier_PD=1 then conception_date=nextssn_calving-282;*late pregnancy count with subsequent calvings;
run;

proc sql;
alter table master1
  modify conception_date format=DDMMYY10.;
quit;

data master1;
set master1;
if conception_date>0 and conception_date<mating1 then outlier_conception_date=1;
run;

proc freq data=master1; *16;
tables outlier_conception_date;
run;

*53 had negative values for SMCO;
data master1;
set master1;
if conception_date>0 and conception_date<mating1 then conception_date1=mating1;
if conception_date>0 and conception_date<ffr_mating_start_date_key then conception_date1=mating1;
else conception_date1=conception_date;
run;

proc sql;
alter table master1
  modify conception_date1 format=DDMMYY10.;
quit;

data master1 (drop= SMCO FSCO DO);
set master1;
run;quit;

*Trait calculation with conceptions;
data master1;
set master1;
SMCO=datdif(ffr_mating_start_date_key,conception_date1,'Actual');
FSCO=datdif(mating1,conception_date1,'Actual');
DO=datdif(calving_date,conception_date1,'Actual');
run;quit;


*PR21;
data master1;
set master1;
if SMCO=. then PR21=0;
else if SMCO<0 then PR21=0;
else if 0<=SMCO<21 then PR21=1;
else PR21=0;
run;

*PR42;
data master1;
set master1;
if SMCO=. then PR42=0;
else if SMCO<0 then PR42=0;
else if 0<=SMCO<42 then PR42=1;
else PR42=0;
run;

*PGFS;
data master1;
set master1;
if mating1>0 and last_PD_date=. and conception_date1=. then PGFS=0;
else if mating1>0 and mating2=. and last_PD_date>0 and last_PD_status='pregnant' then PGFS=1;
else if mating1>0 and mating2=. and last_PD_date>0 and last_PD_status='pregnant' then PGFS=1;
else if mating1>0 and mating2=. and last_PD_date>0 and last_PD_status='doubtful' then PGFS=0;
else if mating1>0 and mating2=. and last_PD_date>0 and last_PD_status='empty - not pregnant' then PGFS=0;
else if mating1>0 and mating2=. and conception_date1>0 then PGFS=1;
else if mating1>0 and mating2>0 then PGFS=0;
else if mating1=. and last_PD_date>0 then PGFS=0;
run;

proc means data=master1;
var SMFS SMCO FSCO DO CFS CI Mating_length SR21 SR42 PR21 PR42 PGFS;
run;

*Milk solid;
data master1;
set master1;
MSY=fat_305+protein_305;
run;quit;

*NIC;
data master1;
set master1;
if last_PD_date=. and nextssn_calving>0 then NIC=0;
else if last_PD_status='pregnant' then NIC=0;
else if last_PD_status='empty - not pregnant' then NIC=1; *empty;
else if last_PD_status='doubtful' then NIC=1;*doubtful;
run;quit;

proc freq data=master1;
tables NIC;
run;quit;

*data master2;
set master2;
if pregnancy='pregnant' then NIC1=0;
if pregnancy='empty' then NIC1=1;
run;quit;

*peanalised conception; 
data master1;
set master1 ;
if conception_date1=. then penalised_conception=1;
if conception_date1>0 then penalised_conception=0;
run;quit;

*1155;
proc freq data=master1;
tables penalised_conception;
run;quit;

data master1;
set master1;
if conception_date1='.' then penalised_conception1=ffr_mating_end_date_key+21; 
run;quit;

proc sql;
alter table master1
  modify penalised_conception1 format=DDMMYY10.;
quit;

data master1;
set master1;
if conception_date1='.' then SMCO1=(datdif(ffr_mating_start_date_key,penalised_conception1,'Actual')+1);
if conception_date1>0 then SMCO1=(datdif(ffr_mating_start_date_key,conception_date1,'Actual')+1);
if mating1>0 and conception_date1='.' then FSCO1=(datdif(mating1,penalised_conception1,'Actual')+1);
if mating1>0 and conception_date1>0 then FSCO1=(datdif(mating1,conception_date1,'Actual')+1);
if conception_date1='.' then DO1=(datdif(calving_date,penalised_conception1,'Actual')+1);
if conception_date1>0 then DO1=(datdif(calving_date,conception_date1,'Actual')+1);
run;quit;


*LastAI dates of D1 and D4 seasonwise;
proc univariate data=D1d4_mating;
  class owner_ptpt_code;
  var mating_date_new;    
  histogram mating_date_new/ nrows=1 odstitle="Histrogram of mating date in D1 and D4";
  ods select histogram;
  where owner_ptpt_code in ('CDBH','CBYC') and season_key= 2014; 
run;quit;

proc univariate data=D1d4_mating;
  class owner_ptpt_code;
  var mating_date_new;    
  histogram mating_date_new/ nrows=1 odstitle="Histrogram of mating date in D1 and D4";
  ods select histogram;
  where owner_ptpt_code in ('CDBH','CBYC') and season_key= 2015; 
run;quit;

proc univariate data=D1d4_mating;
  class owner_ptpt_code;
  var mating_date_new;    
  histogram mating_date_new/ nrows=1 odstitle="Histrogram of mating date in D1 and D4";
  ods select histogram;
  where owner_ptpt_code in ('CDBH','CBYC') and season_key= 2016; 
run;quit;

proc univariate data=D1d4_mating;
  class owner_ptpt_code;
  var mating_date_new;    
  histogram mating_date_new/ nrows=1 odstitle="Histrogram of mating date in D1 and D4";
  ods select histogram;
  where owner_ptpt_code in ('CDBH','CBYC') and season_key= 2017; 
run;quit;

*In CBYC herd had one mating record in 23/04/2019;
proc univariate data=D1d4_mating;
  class owner_ptpt_code;
  var mating_date_new;    
  histogram mating_date_new/ nrows=1 odstitle="Histrogram of mating date in D1 and D4";
  ods select histogram;
  where owner_ptpt_code in ('CDBH','CBYC') and season_key= 2018; 
run;quit;

proc univariate data=D1d4_mating;
  class owner_ptpt_code;
  var mating_date_new;    
  histogram mating_date_new/ nrows=1 odstitle="Histrogram of mating date in D1 and D4";
  ods select histogram;
  where owner_ptpt_code in ('CDBH','CBYC') and season_key= 2019; 
run;quit;

proc univariate data=D1d4_mating;
  class owner_ptpt_code;
  var mating_date_new;    
  histogram mating_date_new/ nrows=1 odstitle="Histrogram of mating date in D1 and D4";
  ods select histogram;
  where owner_ptpt_code in ('CDBH','CBYC') and season_key= 2020; 
run;quit;

proc univariate data=D1d4_mating;
  class owner_ptpt_code;
  var mating_date_new;    
  histogram mating_date_new/ nrows=1 odstitle="Histrogram of mating date in D1 and D4";
  ods select histogram;
  where owner_ptpt_code in ('CDBH','CBYC') and season_key= 2021; 
run;quit;

data master1 (drop=Herd_ssn farm Herd_ssn1 farm1 breed sex Parity Family_ID);
set master1;
run;quit;

proc sort data=Master1 out=Master2;
by farm1 season_year last_mating_date;
run;

data Master2;
 set Master2;
 by farm1 season_year last_mating_date;
 lmd=lag(last_mating_date);* the column of lmd gives the last mating date prior to the more than 7 days;
 if first.farm1 then lmd=.;
 format lmd DDMMYY10.;
 lmd_int=last_mating_date-lmd;
run; quit;

*remove the last AI date of animal_id=34850849 in D1 ssn 2018;
*6956;
data Master2;
 set Master2;
 if  lmd_int>7 then delete;
 run;quit;

Proc sql;
create table Last_AIdate as
select farm1,season_year,lic_animal_key,last_mating_date,max(last_mating_date) as end_lastAI format=DDMMYY10.
from Master2
group by farm1,season_year
order by farm1, season_year;
run;quit;

*I sorted the column of end_lastAI in decending and remove the duplicates;
proc sort data=Last_AIdate nodupkey out=Last_AIdate1;
by farm1 season_year;
run;quit;

data Last_AIdate1 (drop=lic_animal_key last_mating_date);
set Last_AIdate1;
run;quit;

data master1 (drop=end_lastAI SMFS1 CFS1);
set master1;
run;quit;

proc sql;
 create table master1 as
    select distinct  x.*, y. end_lastAI
    from master1 x left join Last_aidate y
    on (x. farm1=y. farm1) and (x. season_year= y. season_year)
    order by lic_animal_key, season_year;
run; quit;

*N=291 records dont have the first service records;
*First service penalised to the Last AI in each herd and add one date for each interval;
data master1;
set master1;
if mating1=. then SMFS1=(datdif(ffr_mating_start_date_key,end_lastAI,'Actual')+1);
if mating1>0 then SMFS1=(datdif(ffr_mating_start_date_key,mating1,'Actual')+1);
if mating1=. then CFS1=(datdif(calving_date,end_lastAI,'Actual')+1);
if mating1>0 then CFS1=(datdif(calving_date,mating1,'Actual')+1);
run;quit;


data master1(drop=penalised_calving1 CI1);
set master1;
run;quit;

data master1;
set master1;
if last_PD_status='pregnant' and conception_date1>0 and CI='.' then penalised_calving1=conception_date1+282;
if last_PD_status='pregnant' and conception_date1>0 and CI='.' then CI1_cow=1;
run;quit;

proc sql;
alter table master1
  modify penalised_calving1 format=DDMMYY10.;
quit;

*1164;
proc freq data=master1;
tables CI1_cow;
run;quit;

data master1;
set master1;
if CI>0 then CI1=CI;
if CI='.' and last_PD_status='pregnant' and conception_date1>0 then CI1=datdif(calving_date,penalised_calving1,'Actual');
run;quit;


*animal_key=5015;*lic_animal_key=6820;*after comibing animal_key 6477;
proc sql;
 create table master1 as
    select distinct  x.*, y.animal_key, y.farm
    from master1 x left join mmaster y
    on (x.lic_animal_key=y.animal_key)
    order by lic_animal_key, season_year;
run; quit;

proc freq data=master1;
tables farm*season_year;
run;quit;

proc freq data=master1;
tables farm*season_year;
where PD_date1>0;
run;quit;

*with repeated PD records;
proc freq data=D1d4_pd;
tables owner_ptpt_code*season_year;
run;quit;

*create contemporary group;
*480 dont have herd_ssn;
data master1;
set master1;
Herd_ssn=catx("_", farm, season_year);
Herd_ssn1=catx("_", farm1, season_year);*according to LIC data;
if herd_name='Massey University No 4' then farm1="D4";
if herd_name='Massey University No 1' then farm1="D1";
run;quit;

proc freq data=a;
tables farm*farm1;
run;quit;

*data aaa;
set master1;
hd=scan(Herd_ssn,1,'_');
ssn=scan(Herd_ssn,2,'_');
run;quit;

*Mistakenly I drop the season_year column;
*proc sql;
 create table master1 as
    select distinct  x.*, y.season_year
    from master1 x left join D1d4_calving y
    on (x.lic_animal_key=y.lic_animal_key)and (x.birth_id=y.birth_id) and (x.birth_date=y.birth_date) and (x.partn_date_key=y.partn_date_key) and (x.calving_date=y.calving_date)
    order by lic_animal_key, season_year;
run; quit;

*code breed;
data Master1;
set Master1; 
if P_HF>=0.875 then breed='F';
if P_J>=0.875 then breed='J';
if 0.875>P_HF>=0 and 0.875>P_J>=0 then breed='FJ';
if lic_animal_key>0 the sex=1;
run;quit;

proc sql;
alter table master1
modify breed char(60) format=$6.;
run;quit;

proc freq data=Master1;
tables breed;
run;quit;

*code family ID for GCTA;
data Master1;
set Master1; 
Parity=ACY-1;
if breed='F' then Family_ID=1;
if breed='FJ' then Family_ID=2;
if breed='J' then Family_ID=3;
run;quit;

*GWAS with GCTA;
proc sql;
 create table master1_GWAS as
    select distinct lic_animal_key,birth_id, sire_lic_animal_key,dam_lic_animal_key,season_year,P_HF,P_J,hfxj, breed,Family_ID,sex,ACY,farm,farm1,Herd_ssn,Herd_ssn1,
     birth_date,calving_date,mating1,mating2, mating3, mating4, mating5, last_mating_date,last_PD_date,last_PD_status,last_PD_count,Left_before_Mating_enddate,pregnancy,conception_date1,
     dmcd,lactation_number,days_in_milk,volume_305,fat_305,protein_305,lactose_305,MSY,FP,PP,LP,
     SMFS,SMFS1,SMCO,SMCO1,FSCO,FSCO1,CFS,CFS1,DO,DO1,CI,CI1,SR21,SR42,PR21,PR42,PGFS,NIC,calving_ssn_day,CR21,CR42
    from master1
    order by lic_animal_key,season_year;
run; quit;

*Create parity 1,2,3,4 and 5=>;
data master1_GWAS;
set master1_GWAS;
if lactation_number=1 then parity=1;
if lactation_number=2 then parity=2;
if lactation_number=3 then parity=3;
if lactation_number=4 then parity=4;
if lactation_number>=5 then parity=5;
run;quit;

*1527;
data master1_GWASP1;
set master1_GWAS;
if lactation_number^=1 then delete;
run;quit;