
/*NHIS-NSC ver2.0 Demo data*/
/*�Գ��� ���Ǽҵ� ���� �� �Ϻ� �Ǽ� �ڷ� ���� �ڵ� */
PROC IMPORT OUT=M20  DATAFILE="D:\EUMC\�����Ͱ���\ǥ����ȣƮ2.0 DB_DEMO\NSC2_M20_1000.xlsx" DBMS=  XLSX   REPLACE;  SHEET="NSC2_M20_1000"; RUN;
PROC IMPORT OUT=BND  DATAFILE="D:\EUMC\�����Ͱ���\ǥ����ȣƮ2.0 DB_DEMO\NSC2_BND_1000.xlsx" DBMS=  XLSX   REPLACE;  SHEET="NSC2_BND_1000";RUN;
PROC IMPORT OUT=BNC DATAFILE="D:\EUMC\�����Ͱ���\ǥ����ȣƮ2.0 DB_DEMO\NSC2_BNC_1000.xlsx" DBMS=  XLSX   REPLACE;  SHEET="NSC2_BNC_1000";RUN;

DATA M20_R; set M20; 
KEEP RN_INDI RN_KEY MDCARE_STRT_DT FORM_CD SICK_SYM1 MDCARE_DD_CNT VSHSP_DD_CNT TOT_PRSC_DD_CNT FST_HSPTZ_DT; RUN;

/*BNC �����ڷ�:�ڰ�����, ID, ���ؿ���,����, �ñ���, ������ ����, ����� ��Ÿ ��� */
/*BND �����ڷ�:���, ��� ���� (n=1,000)  */
DATA BNC_R ; set BNC; 
SIDO = SUBSTR(SGG,1,2);
KEEP RN_INDI STD_YYYY SEX SGG SIDO ; RUN;

PROC SQL; CREATE TABLE JK AS SELECT * FROM BNC_R AS A LEFT JOIN BND AS B ON A.RN_INDI =B.RN_INDI; QUIT;

/*STEP 0.�ڰ� �ڷ� ���� */
DATA JK; SET JK; 
AGE=STD_YYYY-BTH_YYYY;
PKEY=COMPRESS(STD_YYYY)||("-")||COMPRESS(RN_INDI);
IF RN_INDI ="" THEN DELETE;
IF SEX IN ("1","2");
IF SIDO =" " THEN DELETE;
IF AGE =" " THEN DELETE;
RUN;

PROC SORT DATA=JK; BY RN_INDI STD_YYYY; RUN;

/*STEP 1. ������ȯ �ڷ� ���� -> ��ü �������� ����(ICD-10: ��ü I �ڵ�)*/
/*�����ڷῡ�� ���ڵ尡 �ֻ�/��1�λ� ���� �ִµ� 1,000�� ����̴� �ֻ󺴸� ���*/
DATA CVD; SET M20_R; 
IF SUBSTR(SICK_SYM1,1,1)="I";
YY=SUBSTR(MDCARE_STRT_DT,1,4);
MM=SUBSTR(MDCARE_STRT_DT,5,2);
DD=SUBSTR(MDCARE_STRT_DT,7,2);
PKEY=COMPRESS(YY)||("-")||COMPRESS(RN_INDI); /*������ ID �ڷ� ���� (�ڰ��ڷ�� merge ����)*/
RUN;

PROC SQL; SELECT COUNT(DISTINCT RN_INDI) AS CNT FROM CVD; QUIT; /* n= 374*/

/*STEP 2. ������ȯ �ڷ�+�ڰ��ڷ� merge*/
PROC SQL; CREATE TABLE CVD2 AS SELECT * FROM CVD AS A LEFT JOIN JK AS B ON A.PKEY = B.PKEY; QUIT;

/*��Ī ��� ���� -> ����, �õ��� ��Ī���� �ʴ� �ڷ� �Ϻ� ���� */
PROC FREQ DATA=CVD2; TABLES SEX; RUN;
PROC FREQ DATA=CVD2; TABLES SIDO; RUN;
PROC FREQ DATA=CVD2; TABLES AGE; RUN;

/*STEP 3. ������ Ŭ����  */
DATA CVD3; SET CVD2;
/*�ǰ��Կ��� ��츸 */
IF FORM_CD IN ("02");
/*��¥ ��ȿ�� ��� ���� */
IF '1899' <=SUBSTR(FST_HSPTZ_DT,1,4) <="2021" and "01" <= substr(FST_HSPTZ_DT,5,2)<="12" AND 
"01" <= SUBSTR(FST_HSPTZ_DT,7,2) <= "31" THEN FST_HSPTZ_DT=FST_HSPTZ_DT; ELSE FST_HSPTZ_DT="";

IF SEX IN ("1","2");
IF SIDO =" " THEN DELETE;
IF AGE =" " THEN DELETE;

/*��ȿ�� �Գ��� �ϼ� ���� */
IF VSHSP_DD_CNT="" THEN DELETE;               
/*�Կ����� �ϼ��� 0�ΰ��� �Կ��� �ߴٰ� ������ ���� ���Ḧ �޾Ƽ� ������ 0-> 1�� ���� */
IF VSHSP_DD_CNT=0 THEN VSHSP_DD_CNT=1;  
RUN;

/*STEP 4. ������ ��ó�� �� �Գ����ϼ� ����� ���� ����  */
DATA CVD4; SET CVD3;
FORMAT RECU FST RECU_DATE FST_DATE DATE1 yymmdd10.;
/*��� ��������*/
RECU=MDY(MM,DD,YY);

/*�����Կ���, �Կ��� ��� �ش� ���� ���� ������ ��¥ */
FST=MDY(substr(FST_HSPTZ_DT,5,2),SUBSTR(FST_HSPTZ_DT,7,2),SUBSTR(FST_HSPTZ_DT,1,4));

/*���� �Կ����� �ִ� ��� 1, �ƴϸ� 0*/
IF FST^=" " THEN FST_STATUS=1; ELSE FST_STATUS=0;

/*���� ������ ���*/
IF RECU=" " THEN RECU_DATE=FST; ELSE RECU_DATE=RECU; /*RECU�� �����̸� FST�� �Է�, ������ �ƴϸ� RECU�� �Է�*/
IF FST  ^=" " THEN FST_DATE=FST;                                           /*FST(�����Կ���)�� ������ �ƴϸ� FST_DATE  �Է�, �����̸�  RECU�� �Է�*/
DATE1=min(FST_DATE,RECU_DATE);      /*���� �����ϰ� �����Կ��� ���� �ڷῡ�� �� �� �����γ� */
DIFF_PLUS=RECU_DATE-DATE1;            /*��簳������- �� ó�� �Կ���� �����ѳ� ����*/
CNT_DD=DIFF_PLUS+VSHSP_DD_CNT;  /*(��簳������-�� ó�� �Կ������)+�Գ��� �ϼ� => ó�� ��ȯ�� �߻��� �ñ���� ������ ����� �� */

/*��簳����+���ξ��̵�� ���ο� KEY �ο� (�� ȯ�ڰ� ���� �� ������ �Ǽ� �ִ� ��� ������ ���ؿ� ���� �ߺ� �����ϱ� ����)*/
/*�ֻ�, �λ���  �� �ֻ��� �ִٰų�, �Գ����ϼ��� �� ���̰ų� �� (�����ڷῡ���� ���� X) */
DKEY=COMPRESS(MDCARE_STRT_DT)||("-")||COMPRESS(RN_INDI); RUN;

PROC SORT DATA=CVD4; BY DKEY DESCENDING CNT_DD; RUN;

PROC SQL; CREATE TABLE Z AS SELECT DKEY , COUNT(DKEY) AS CNT FROM CVD4 GROUP BY DKEY; QUIT;


/*STEP 5. ���� ��ȯ���� ���� �Կ� ȯ�ڿ� ���� ���� ��¥ û���� ���� */
/*�����ڷῡ���� ������ �ߺ��Ǵ� ȯ���� ���� �� �Գ����ϼ��� �����ϴ� �ڷḸ �츮�� */
DATA CVD5; SET CVD4;
BY DKEY; IF FIRST.DKEY^=1 THEN DELETE; RUN;

PROC SORT DATA=CVD5; BY RN_INDI RECU_DATE; RUN;

/*STEP 6. ���Ǽҵ� ���� */
DATA CVD6; SET CVD5;
FORMAT R START_DATE YYMMDD10.;
RETAIN R D START_DATE ; SET CVD5; BY RN_INDI;

/*ù�൵ ������ ���� ȯ�ڶ�� IKEEP=1*/
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

/*���ӵ� �Գ��� �ϼ��� ������ �����¥- �����Կ���¥�� ���*/
/*���� �������� R�� ���� ȯ�ڿ� ���ؼ� ���� ���� ������ ���� ����*/
/*k�� � ȯ�ڰ� ���������� ���Ḧ �޴µ� �־ ó�� ���ᰡ ���� ���� ���� ���� ���Ḧ �޴� TERM�� �ǹ� */

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

/*STEP 7. ���Ǽҵ� ���� */
DATA CVD7; SET CVD6;
FORMAT DISCHARGEDATE YYMMDD10.;

/*�������� �Կ�ȯ���� �� �ϼ� ���*/
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
if _n_ in(1) then ikeep2=1;                  /*lag ������ �� ó�� ���� �սǵ� �� ������.. �츮������ */
IF IKEEP2=1;
run;

/*���� �Ǽ� �ڷ� (daily count)*/

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
