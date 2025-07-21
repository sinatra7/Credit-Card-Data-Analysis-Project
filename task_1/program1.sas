/* Define file path */
%LET filepath = /home/u64269485/sasuser.v94/Credit Banking_Project - 1.xls;
FILENAME REFFILE "&filepath";

/* Import Customer Acqusition */
PROC IMPORT DATAFILE=REFFILE
    DBMS=XLS
    OUT=WORK.CUSTOMER
    REPLACE;
    SHEET="Customer Acqusition";
    GETNAMES=YES;
RUN;

/* Import Spend */
PROC IMPORT DATAFILE=REFFILE
    DBMS=XLS
    OUT=WORK.SPEND
    REPLACE;
    SHEET="Spend";
    GETNAMES=YES;
RUN;

/* Import Repayment */
PROC IMPORT DATAFILE=REFFILE
    DBMS=XLS
    OUT=WORK.REPAYMENT
    REPLACE;
    SHEET="Repayment";
    GETNAMES=YES;
RUN;

/* Clean SPEND */
DATA WORK.SPEND_CLEAN;
    SET WORK.SPEND;
    LENGTH Customer $12;
    Customer = Costomer;
    Spend_Amount = Amount;
    IF Spend_Amount <= 0 THEN Spend_Amount = .;
    FORMAT Month MONYY7.;
    KEEP Customer Month Spend_Amount Type;
RUN;

/* Clean REPAYMENT */
DATA WORK.REPAYMENT_CLEAN;
    SET WORK.REPAYMENT;
    LENGTH Customer $12;
    Customer = Costomer;
    Repayment_Amount = Amount;
    IF Repayment_Amount <= 0 THEN Repayment_Amount = .;
    FORMAT Month MONYY7.;
    KEEP Customer Month Repayment_Amount;
RUN;

/* Clean CUSTOMER */
DATA WORK.CUSTOMER_CLEAN;
    SET WORK.CUSTOMER;
    IF Age <= 0 OR Age < 18 THEN Age = .;
RUN;

/* Join datasets */
PROC SQL;
    CREATE TABLE WORK.MERGED AS
    SELECT c.Customer,
           c.Age,
           c.City,
           c.Segment,
           c.Limit,
           c.'Credit Card Product'n,
           s.Month,
           s.Type AS Spend_Category,
           COALESCE(s.Spend_Amount, 0) AS Spend_Amount,
           COALESCE(r.Repayment_Amount, 0) AS Repayment_Amount
    FROM WORK.CUSTOMER_CLEAN c
    LEFT JOIN WORK.SPEND_CLEAN s
        ON c.Customer = s.Customer
    LEFT JOIN WORK.REPAYMENT_CLEAN r
        ON c.Customer = r.Customer AND s.Month = r.Month
    ORDER BY c.Customer, s.Month;
QUIT;

/* Assign Age_Group with adult categories */
DATA WORK.MERGED;
    SET WORK.MERGED;
    LENGTH Age_Group $20;
    IF Age = . THEN Age_Group = '<18';
    ELSE IF 18 <= Age <= 29 THEN Age_Group = 'Young Adult (18–29)';
    ELSE IF 30 <= Age <= 50 THEN Age_Group = 'Adult (30–50)';
    ELSE IF 51 <= Age <= 65 THEN Age_Group = 'Middle-aged (51–65)';
    ELSE IF Age > 65 THEN Age_Group = 'Senior (65+)';
    ELSE Age_Group = 'Unknown';
RUN;

/* Data quality check: Original Age_Group distribution with Child and Adolescent */
DATA WORK.MERGED_CHECK;
    SET WORK.CUSTOMER;
    LENGTH Age_Group $20;
    IF Age = . THEN Age_Group = '<18';
    ELSE IF 0 <= Age <= 29 THEN Age_Group = 'Young Adult (18–29)';
    ELSE IF 30 <= Age <= 50 THEN Age_Group = 'Adult (30–50)';
    ELSE IF 51 <= Age <= 65 THEN Age_Group = 'Middle-aged (51–65)';
    ELSE IF Age > 65 THEN Age_Group = 'Senior (65+)';
    ELSE Age_Group = 'Unknown';
RUN;

PROC FREQ DATA=WORK.MERGED_CHECK;
    TABLES Age_Group * Spend_Amount / LIST MISSING NOROW NOCOL NOPERCENT;
    TITLE "Spend_Amount Distribution by Original Age_Group (Including Child and Adolescent)";
RUN;


/* Monthly Spend and Repayment */
PROC SQL;
    CREATE TABLE WORK.MonthlySpendRepay AS
    SELECT s.Customer,
           s.Month,
           s.Monthly_Spend,
           COALESCE(r.Monthly_Repayment, 0) AS Monthly_Repayment FORMAT=COMMA20.
    FROM (
        SELECT Customer, Month, SUM(Spend_Amount) AS Monthly_Spend FORMAT=COMMA20.
        FROM WORK.MERGED
        WHERE Spend_Amount > 0
        GROUP BY Customer, Month
    ) s
    LEFT JOIN (
        SELECT Customer, Month, SUM(Repayment_Amount) AS Monthly_Repayment FORMAT=COMMA20.
        FROM WORK.MERGED
        WHERE Repayment_Amount > 0
        GROUP BY Customer, Month
    ) r
        ON s.Customer = r.Customer AND s.Month = r.Month
    ORDER BY s.Customer, s.Month;
QUIT;

/* Random sample of 15 customers */
PROC SURVEYSELECT DATA=WORK.MonthlySpendRepay OUT=WORK.MonthlySpendRepay_Sample
                  METHOD=SRS SAMPSIZE=15 SEED=12345;
    ID Customer Month Monthly_Spend Monthly_Repayment;
RUN;

PROC PRINT DATA=WORK.MonthlySpendRepay_Sample;
    TITLE "Monthly Spend and Repayment by Customer (Sample)";
RUN;


/* Top 10 Repayers */
PROC SQL OUTOBS=10;
    CREATE TABLE WORK.Top10Repayers AS
    SELECT Customer,
           SUM(Repayment_Amount) AS Total_Repayment FORMAT=COMMA20.
    FROM WORK.MERGED
    GROUP BY Customer
    ORDER BY Total_Repayment DESC;
QUIT;

PROC PRINT DATA=WORK.Top10Repayers;
    TITLE "Customers by Total Repayment";
RUN;

PROC SGPLOT DATA=WORK.Top10Repayers;
    TITLE "Customers by Total Repayment";
    VBAR Customer / RESPONSE=Total_Repayment DATALABEL FILLATTRS=(COLOR=BLUE) DATASKIN=GLOSS;
    XAXIS LABEL="Customer" FITPOLICY=ROTATE;
    YAXIS LABEL="Total Repayment (INR)" GRID;
    FORMAT Total_Repayment COMMA20.;
RUN;

/* Total Spend by Segment */
PROC SQL;
    CREATE TABLE WORK.SegmentSpend AS
    SELECT Segment,
           SUM(Spend_Amount) AS Total_Spend FORMAT=COMMA20.
    FROM WORK.MERGED
    GROUP BY Segment
    ORDER BY Total_Spend DESC;
QUIT;

PROC SGPLOT DATA=WORK.SegmentSpend;
    TITLE "Total Spend by Segment";
    VBAR Segment / RESPONSE=Total_Spend DATALABEL FILLATTRS=(COLOR=GREEN) DATASKIN=GLOSS;
    XAXIS LABEL="Segment" FITPOLICY=ROTATE;
    YAXIS LABEL="Total Spend (INR)" GRID;
    FORMAT Total_Spend COMMA20.;
RUN;

/* Total Spend by Age Group */
PROC SQL;
    CREATE TABLE WORK.AgeGroupSpend AS
    SELECT Age_Group,
           SUM(Spend_Amount) AS Total_Spend
    FROM WORK.MERGED
    GROUP BY Age_Group
    HAVING Total_Spend > 0;
QUIT;

PROC PRINT DATA=WORK.AgeGroupSpend;
    TITLE "Total Spend by Age Group";
RUN;

PROC SGPLOT DATA=WORK.AgeGroupSpend;
    TITLE "Total Spend by Age Group";
    HBAR Age_Group / RESPONSE=Total_Spend
                     DATALABEL
                     GROUP=Age_Group
                     GROUPDISPLAY=CLUSTER
                     DATASKIN=MATTE
                     CATEGORYORDER=RESPDESC;
    YAXIS LABEL="Age Group" 
          LABELATTRS=(SIZE=12PT)
          VALUEATTRS=(SIZE=10PT);
    XAXIS LABEL="Total Spend (INR)" 
          GRID 
          MIN=0 
          LABELATTRS=(SIZE=12PT)
          VALUEATTRS=(SIZE=10PT);
    FORMAT Total_Spend COMMA20.;
RUN;

/* Monthly Profit Calculation */
DATA WORK.MERGED_PROFIT;
    SET WORK.MERGED;
    Due_Amount = Spend_Amount - Repayment_Amount;
    IF Due_Amount < 0 THEN Due_Amount = 0;
    Interest = Due_Amount * 0.029; /* 2.9% interest on unpaid balance */
    Profit = Interest;
    IF Due_Amount > Limit THEN PUT "WARNING: Due_Amount exceeds Limit for Customer=" Customer;
RUN;

/* Most Profitable Segment */
PROC SQL;
    CREATE TABLE WORK.SegmentProfit AS
    SELECT Segment,
           SUM(Profit) AS Total_Profit FORMAT=COMMA20.
    FROM WORK.MERGED_PROFIT
    GROUP BY Segment
    ORDER BY Total_Profit DESC;
QUIT;

PROC PRINT DATA=WORK.SegmentProfit;
    TITLE "Most Profitable Segment";
RUN;

PROC SGPLOT DATA=WORK.SegmentProfit;
    TITLE "Most Profitable Segment";
    VBAR Segment / RESPONSE=Total_Profit
                   DATALABEL
                   GROUP=Segment
                   GROUPDISPLAY=CLUSTER
                   DATASKIN=MATTE;
    XAXIS LABEL="Segment" FITPOLICY=ROTATE 
          LABELATTRS=(SIZE=12PT)
          VALUEATTRS=(SIZE=10PT);
    YAXIS LABEL="Total Profit (INR)" GRID 
          LABELATTRS=(SIZE=12PT)
          VALUEATTRS=(SIZE=10PT);
    FORMAT Total_Profit COMMA20.;
RUN;

/* Spend by Category */
PROC SQL;
    CREATE TABLE WORK.CategorySpend AS
    SELECT Spend_Category AS Category,
           SUM(Spend_Amount) AS Total_Spend FORMAT=COMMA20.
    FROM WORK.MERGED
    WHERE Spend_Category IS NOT NULL
    GROUP BY Spend_Category
    ORDER BY Total_Spend DESC;
QUIT;

PROC PRINT DATA=WORK.CategorySpend;
    TITLE "Total Spend by Category (Spend Type)";
RUN;

PROC SGPLOT DATA=WORK.CategorySpend;
    TITLE "Total Spend by Category";
    VBAR Category / RESPONSE=Total_Spend
                    DATALABEL
                    FILLATTRS=(COLOR=TEAL)
                    DATASKIN=MATTE;
    XAXIS LABEL="Spend Category" FITPOLICY=ROTATE;
    YAXIS LABEL="Total Spend (INR)" GRID;
    FORMAT Total_Spend COMMA20.;
RUN;

/* Monthly Profit */
PROC SQL;
    CREATE TABLE WORK.MonthlyProfit AS
    SELECT Month,
           SUM(Profit) AS Monthly_Profit FORMAT=COMMA20.
    FROM WORK.MERGED_PROFIT
    WHERE Month IS NOT NULL
    GROUP BY Month
    ORDER BY Month;
QUIT;

PROC PRINT DATA=WORK.MonthlyProfit;
    TITLE "Monthly Profit for the Bank";
RUN;

PROC SGPLOT DATA=WORK.MonthlyProfit;
    TITLE "Monthly Profit for the Bank";
    SERIES X=Month Y=Monthly_Profit /
           LINEATTRS=(COLOR=BLUE THICKNESS=1);
    XAXIS LABEL="Month" INTERVAL=MONTH GRID VALUESHINT;
    YAXIS LABEL="Monthly Profit (INR)" GRID;
    FORMAT Monthly_Profit COMMA20.;
RUN;

/* Customers Over Credit Limit */
PROC SQL;
    CREATE TABLE WORK.OverLimit AS
    SELECT Customer,
           Month,
           Limit,
           SUM(Spend_Amount) AS Monthly_Spend FORMAT=COMMA20.
    FROM WORK.MERGED
    WHERE Month IS NOT NULL
    GROUP BY Customer, Month, Limit
    HAVING Monthly_Spend > Limit
    ORDER BY Customer, Month;
QUIT;

PROC PRINT DATA=WORK.OverLimit;
    TITLE "Customers Exceeding Credit Limit";
RUN;

PROC SQL;
    CREATE TABLE WORK.OverLimit_Sample AS
    SELECT Customer, Month, Monthly_Spend
    FROM WORK.OverLimit(OBS=10);
QUIT;