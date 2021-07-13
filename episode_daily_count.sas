
/*NHIS-NSC ver2.0 Demo data*/
/*입내원 에피소드 정리 및 일별 건수 자료 산출 코드 */
PROC IMPORT OUT=M20  DATAFILE="D:\EUMC\데이터관리\표본코호트2.0 DB_DEMO\NSC2_M20_1000.xlsx" DBMS=  XLSX   REPLACE;  SHEET="NSC2_M20_1000"; RUN;
PROC IMPORT OUT=BND  DATAFILE="D:\EUMC\데이터관리\표본코호트2.0 DB_DEMO\NSC2_BND_1000.xlsx" DBMS=  XLSX   REPLACE;  SHEET="NSC2_BND_1000";RUN;
PROC IMPORT OUT=BNC DATAFILE="D:\EUMC\데이터관리\표본코호트2.0 DB_DEMO\NSC2_BNC_1000.xlsx" DBMS=  XLSX   REPLACE;  SHEET="NSC2_BNC_1000";RUN;

DATA M20_R; set M20; 
KEEP RN_INDI RN_KEY MDCARE_STRT_DT FORM_CD SICK_SYM1 MDCARE_DD_CNT VSHSP_DD_CNT TOT_PRSC_DD_CNT FST_HSPTZ_DT; RUN;

/*BNC 데모자료:자격정보, ID, 기준연도,성별, 시군구, 가입자 유형, 보험료 기타 등등 */
/*BND 데모자료:출생, 사망 정보 (n=1,000)  */
DATA BNC_R ; set BNC; 
SIDO = SUBSTR(SGG,1,2);
KEEP RN_INDI STD_YYYY SEX SGG SIDO ; RUN;

PROC SQL; CREATE TABLE JK AS SELECT * FROM BNC_R AS A LEFT JOIN BND AS B ON A.RN_INDI =B.RN_INDI; QUIT;

/*STEP 0.자격 자료 정리 */
DATA JK; SET JK; 
AGE=STD_YYYY-BTH_YYYY;
PKEY=COMPRESS(STD_YYYY)||("-")||COMPRESS(RN_INDI);
IF RN_INDI ="" THEN DELETE;
IF SEX IN ("1","2");
IF SIDO =" " THEN DELETE;
IF AGE =" " THEN DELETE;
RUN;

PROC SORT DATA=JK; BY RN_INDI STD_YYYY; RUN;

/*STEP 1. 관심질환 자료 추출 -> 전체 심혈관을 예시(ICD-10: 전체 I 코드)*/
/*데모자료에는 상병코드가 주상병/제1부상병 까지 있는데 1,000명 대상이니 주상병만 고려*/
DATA CVD; SET M20_R; 
IF SUBSTR(SICK_SYM1,1,1)="I";
YY=SUBSTR(MDCARE_STRT_DT,1,4);
MM=SUBSTR(MDCARE_STRT_DT,5,2);
DD=SUBSTR(MDCARE_STRT_DT,7,2);
PKEY=COMPRESS(YY)||("-")||COMPRESS(RN_INDI); /*연도별 ID 자료 생성 (자격자료와 merge 목적)*/
RUN;

PROC SQL; SELECT COUNT(DISTINCT RN_INDI) AS CNT FROM CVD; QUIT; /* n= 374*/

/*STEP 2. 관심질환 자료+자격자료 merge*/
PROC SQL; CREATE TABLE CVD2 AS SELECT * FROM CVD AS A LEFT JOIN JK AS B ON A.PKEY = B.PKEY; QUIT;

/*매칭 결과 검토 -> 성별, 시도는 매칭되지 않는 자료 일부 존재 */
PROC FREQ DATA=CVD2; TABLES SEX; RUN;
PROC FREQ DATA=CVD2; TABLES SIDO; RUN;
PROC FREQ DATA=CVD2; TABLES AGE; RUN;

/*STEP 3. 데이터 클리닝  */
DATA CVD3; SET CVD2;
/*의과입원인 경우만 */
IF FORM_CD IN ("02");
/*날짜 무효한 경우 제외 */
IF '1899' <=SUBSTR(FST_HSPTZ_DT,1,4) <="2021" and "01" <= substr(FST_HSPTZ_DT,5,2)<="12" AND 
"01" <= SUBSTR(FST_HSPTZ_DT,7,2) <= "31" THEN FST_HSPTZ_DT=FST_HSPTZ_DT; ELSE FST_HSPTZ_DT="";

IF SEX IN ("1","2");
IF SIDO =" " THEN DELETE;
IF AGE =" " THEN DELETE;

/*무효한 입내원 일수 제외 */
IF VSHSP_DD_CNT="" THEN DELETE;               
/*입원내원 일수가 0인경우는 입원을 했다가 검진과 같은 진료를 받아서 생긴경우 0-> 1로 변경 */
IF VSHSP_DD_CNT=0 THEN VSHSP_DD_CNT=1;  
RUN;

/*STEP 4. 데이터 전처리 및 입내원일수 계산할 변수 생성  */
DATA CVD4; SET CVD3;
FORMAT RECU FST RECU_DATE FST_DATE DATE1 yymmdd10.;
/*요양 개시일자*/
RECU=MDY(MM,DD,YY);

/*최초입원일, 입원일 경우 해당 월에 최초 내원한 날짜 */
FST=MDY(substr(FST_HSPTZ_DT,5,2),SUBSTR(FST_HSPTZ_DT,7,2),SUBSTR(FST_HSPTZ_DT,1,4));

/*최초 입원일이 있는 경우 1, 아니면 0*/
IF FST^=" " THEN FST_STATUS=1; ELSE FST_STATUS=0;

/*진료 개시일 계산*/
IF RECU=" " THEN RECU_DATE=FST; ELSE RECU_DATE=RECU; /*RECU가 결측이면 FST로 입력, 결측이 아니면 RECU로 입력*/
IF FST  ^=" " THEN FST_DATE=FST;                                           /*FST(최초입원일)가 결측이 아니면 FST_DATE  입력, 결측이면  RECU로 입력*/
DATE1=min(FST_DATE,RECU_DATE);      /*진료 개시일과 최초입원일 기입 자료에서 둘 중 먼저인날 */
DIFF_PLUS=RECU_DATE-DATE1;            /*요양개시일자- 맨 처음 입원요양 시작한날 차이*/
CNT_DD=DIFF_PLUS+VSHSP_DD_CNT;  /*(요양개시일자-맨 처음 입원요양일)+입내원 일수 => 처음 질환이 발생한 시기부터 누적된 요양일 수 */

/*요양개시일+개인아이디로 새로운 KEY 부여 (한 환자가 같은 날 동일한 건수 있는 경우 정의한 기준에 따라 중복 제거하기 위해)*/
/*주상병, 부상병중  중 주상병이 있다거나, 입내원일수가 긴 날이거나 등 (데모자료에서는 적용 X) */
DKEY=COMPRESS(MDCARE_STRT_DT)||("-")||COMPRESS(RN_INDI); RUN;

PROC SORT DATA=CVD4; BY DKEY DESCENDING CNT_DD; RUN;

PROC SQL; CREATE TABLE Z AS SELECT DKEY , COUNT(DKEY) AS CNT FROM CVD4 GROUP BY DKEY; QUIT;


/*STEP 5. 같은 질환으로 인한 입원 환자에 대해 같은 날짜 청구건 정리 */
/*데모자료에서는 같은날 중복되는 환자중 가장 긴 입내원일수가 존재하는 자료만 살리기 */
DATA CVD5; SET CVD4;
BY DKEY; IF FIRST.DKEY^=1 THEN DELETE; RUN;

PROC SORT DATA=CVD5; BY RN_INDI RECU_DATE; RUN;

/*STEP 6. 에피소드 정리 */
DATA CVD6; SET CVD5;
FORMAT R START_DATE YYMMDD10.;
RETAIN R D START_DATE ; SET CVD5; BY RN_INDI;

/*첫행도 끝행이 같은 환자라면 IKEEP=1*/
IF FIRST.RN_INDI=1 AND LAST.RN_INDI=1 THEN 
DO; IKEEP=1;
R=DATE1+CNT_DD-1;
D=CNT_DD;
START_DATE=DATE1;
END; ELSE DO;

IF FIRST.RN_INDI=1 AND LAST.RN_INDI^=1 THEN DO;
IKEEP=1;
R=DATE1+CNT_DD-1;
D=CNT_DD;
START_DATE=DATE1; END;
ELSE DO;

/*연속된 입내원 일수를 마지막 퇴원날짜- 최초입원날짜로 계산*/
/*여기 관점에서 R은 같은 환자에 대해서 이전 진료 행위가 끝난 시점*/
/*k는 어떤 환자가 연속적으로 진료를 받는데 있어서 처음 진료가 끝난 이후 부터 다음 진료를 받는 TERM을 의미 */

K=DATE1-R;
IF K<=2 THEN DO;

IKEEP=0;
IF DATE1+CNT_DD-1<R then d=D; else do;
R=date1+cnt_dd-1;
D=R-START_DATE+1;

END; END; ELSE DO;
IKEEP=1;
R=DATE1+CNT_DD-1;
D=CNT_DD;
START_DATE=DATE1;END;END;END;
DATE1_DISCHARGEDATE=DATE1+CNT_DD-1;RUN;

PROC SORT DATA=CVD6; BY RN_INDI DESENDING RECU_DATE DESENDING CNT_DD; RUN;

/*STEP 7. 에피소드 정리 */
DATA CVD7; SET CVD6;
FORMAT DISCHARGEDATE YYMMDD10.;

/*연속적인 입원환자의 총 일수 계산*/
RETAIN MAXD; SET CVD6; BY RN_INDI;
IF FIRST.RN_iNDI=1 AND IKEEP=0 THEN MAXD=D; ELSE DO;
IF FIRST.RN_INDI=1 AND IKEEP=1 THEN MAXD=0; ELSE DO;
IF IKEEP=0 THEN DO; MAXD=MAX(D,MAXD); END; ELSE DO;  MAXD=0; END; END; END;
IKEEP2=LAG(IKEEP);

IF FIRST.RN_INDI=1 THEN ILOGKEEP=2; ELSE DO;
IF IKEEP2=0             THEN ILOGKEEP=1; ELSE ILOGKEEP=2; END;
D2=LAG(MAXD);

IF IKEEP=1 AND ILOGKEEP=2 THEN D=CNT_DD; ELSE DO;
IF IKEEP=1 AND ILOGKEEP=1 THEN D=D2;       END;

DISCHARGEDATE=START_DATE+D-1;
if _n_ in(1) then ikeep2=1;                  /*lag 떄문에 맨 처음 행은 손실될 수 있으니.. 살리기위해 */
IF IKEEP2=1;
run;

/*일일 건수 자료 (daily count)*/

data dat ; set cvd7;
if age <15 then age0014 =1 ; else age0014=0;
if age>=15 & age<=64 then age1564=1; else age1564=0;
if age>=65 then age65=1; else age65=0;
if sex=1 then male=1; else male=0;
if sex=2 then female=1; else female=0;
run;

proc sql; create table daily_count as select start_date as date,sido, count(start_date) as total, sum(age0014) as age0014, sum(age1564) as age1564, sum(age65) as age65, sum(male) as male, sum(female) as female from
dat group by  date, sido; run;

proc sort data= daily_count; by sido  date; run;
