# Credit Card Data Analysis Project - SAS
* Hrishab Kakoty - hrishabkakoty21@gmail.com *

## Overview
Analyzes credit card data using SAS to compute KPIs like monthly spend, repayment, and profit by segment, age group, and category. As a first-time SAS learner, I faced challenges but gained insights into data cleaning, joins, and visualization.

## Project Structure
- Input: Excel file (Credit Banking_Project - 1.xls) with sheets: Customer Acqusition, Spend, Repayment.
- SAS Code: Cleans data, calculates KPIs, generates bar charts.
- Outputs: Tables (MonthlySpend, SegmentProfit, etc.) and visualizations.

## What I Did
1. Imported Excel sheets using PROC IMPORT.
2. Cleaned data:
   - Fixed typos (Costomer to Customer).
   - Converted Limit to numeric.
   - Set Age < 18 to 18.
3. Calculated KPIs:
   - Monthly spend/repayment per customer.
   - Top 10 customers by monthly repayment.
   - Spend by segment, age group, category.
   - Bank profit with 2.9% interest on cumulative due.
   - Customers exceeding credit limits.
4. Visualized data with PROC SGPLOT bar charts.
5. Added cumulative due for accurate profit tracking.

## Challenges Faced
1. Data Import: Typo in sheet name (Acqusition) caused errors. Fixed by checking names.
2. Data Types: Limit was character (e.g., [$INR] 500,000.00). Used INPUT/COMPRESS to convert.
3. Missing Data: Incomplete customer-month pairs. Created CustomerMonthGrid to fix.
4. Monthly vs. Total: Initially summed repayments across months for top 10. Used RANK() for monthly.
5. Joins: Struggled with PROC SQL left joins. Used COALESCE for missing values.
6. Cumulative Due: Missed carry-over balances initially. Added RETAIN logic.
7. SAS Syntax: Confused WHERE vs. HAVING. Learned proper SQL filtering.
8. Visualization: Customer-level plots were cluttered. Focused on aggregates.

## Lessons Learned
- Verify data types/formats before processing.
- Use grids for complete data coverage.
- PROC SQL is powerful but needs careful syntax.
- RETAIN handles cumulative calculations.
- Aggregate data for clear visualizations.
- Use PROC PRINT with OBS= for debugging.

## How to Run
1. Place Excel file in SAS path (e.g., /home/u64269485/sasuser.v94/).
2. Copy SAS code to SAS editor.
3. Run in SAS Studio or similar.
4. View tables (e.g., WORK.MonthlySpend) and charts in results.

## Future Improvements
- Validate repayment data.
- More Meaningful treatment for age.
- Add time-series visualizations.
