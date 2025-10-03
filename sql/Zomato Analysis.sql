CREATE DATABASE Zomato_Analysis;
USE Zomato_Analysis;

-- Create Zomato main table
CREATE TABLE zomato_main (Restaurant_ID VARCHAR(50), Restaurant_Name VARCHAR(255), Country_Code VARCHAR(10), City VARCHAR(150), Address VARCHAR(500), Locality VARCHAR(150), Cuisines VARCHAR(500), 
Currency VARCHAR(50), Has_Table_booking TEXT, Has_Online_delivery TEXT, Is_delivering_now TEXT, Switch_to_order_menu TEXT, Price_range VARCHAR(50), Votes VARCHAR(50), Average_Cost_for_two VARCHAR(50), 
Rating VARCHAR(50), Year_Opening VARCHAR(10), Month_Opening VARCHAR(10), Day_Opening VARCHAR(10), Date_Opening VARCHAR(20), Datekey_Opening INT);

-- Load Data to zomato main table
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Zomato_main_utf.8.csv'
INTO TABLE zomato_main
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS (Restaurant_ID, Restaurant_Name, Country_Code, City, Address, Locality, Cuisines, Currency, Has_Table_booking, Has_Online_delivery, Is_delivering_now, Switch_to_order_menu, 
Price_range, Votes, Average_Cost_for_two, Rating, Year_Opening, Month_Opening, Day_Opening, Date_Opening, Datekey_Opening);
Select *From zomato_main;

-- Create Calender Table
CREATE TABLE calendar (dt DATE PRIMARY KEY, YearNo INT, MonthNo INT, MonthFullName VARCHAR(20), Quarter VARCHAR(2), YearMonth VARCHAR(9), WeekdayNo INT, WeekdayName VARCHAR(10), 
FinancialMonthNo INT, FinancialQuarter VARCHAR(5));

-- Insert calender with a date generator from 0 to 9999. This table make time-based analysis easier (like restaurant openings per year, per quarter, weekday trends, etc.).
INSERT INTO calendar (dt, YearNo, MonthNo, MonthFullName, Quarter, YearMonth, WeekdayNo, WeekdayName, FinancialMonthNo, FinancialQuarter)
SELECT d.dt, YEAR(d.dt) AS YearNo, MONTH(d.dt) AS MonthNo, MONTHNAME(d.dt) AS MonthFullName, CONCAT('Q', QUARTER(d.dt)) AS Quarter, DATE_FORMAT(d.dt, '%Y-%b') AS YearMonth, 
WEEKDAY(d.dt) + 1 AS WeekdayNo, DAYNAME(d.dt) AS WeekdayName, ((MONTH(d.dt) + 8) % 12) + 1 AS FinancialMonthNo, 
CONCAT('FQ-', FLOOR((( (MONTH(d.dt) + 8) % 12 ) + 1 - 1) / 3) + 1) AS FinancialQuarter
-- If restaurants opened between Min Data and Maximum Date, this will generate every date in that range.
FROM (SELECT DATE_ADD(bounds.min_dt, INTERVAL n.n DAY) AS dt 
FROM (SELECT MIN(STR_TO_DATE(Datekey_Opening, '%Y%m%d')) AS min_dt, MAX(STR_TO_DATE(Datekey_Opening, '%Y%m%d')) AS max_dt FROM zomato_main) AS bounds
JOIN (SELECT a.N + b.N * 10 + c.N * 100 + d.N * 1000 AS n  
	FROM (SELECT 0 AS N UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) a
	CROSS JOIN (SELECT 0 AS N UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) b
	CROSS JOIN (SELECT 0 AS N UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) c
	CROSS JOIN (SELECT 0 AS N UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) d) n
    WHERE DATE_ADD(bounds.min_dt, INTERVAL n.n DAY) <= bounds.max_dt) d
ORDER BY d.dt;
Select *from calendar;
Select *from currency;
Select *from Country;
Select *from zomato_main;
SELECT COUNT(*) FROM zomato_main;

-- Replace NULL ratings with 0
UPDATE zomato_main SET Rating = 0 WHERE Rating IS NULL;

-- Total Restaurants
SELECT COUNT(*) AS Total_Restaurants FROM zomato_main;

-- Currency Conversion (Convert Average_Cost_for_two into USD)
DESCRIBE Currency;
ALTER TABLE Currency CHANGE `USD Rate` USD_Rate DECIMAL(12,6);
SELECT m.Restaurant_ID, m.Restaurant_Name, m.Currency, m.Average_Cost_for_two AS Local_Cost,
Concat('$ ', ROUND(m.Average_Cost_for_two * c.USD_Rate, 2)) AS Cost_USD FROM zomato_main m LEFT JOIN Currency c ON m.Currency = c.Currency;
-- Average Cost for Two in USD
SELECT Concat('$',ROUND(AVG(m.Average_Cost_for_two * c.USD_Rate),2)) AS Avg_Cost_USD FROM zomato_main m LEFT JOIN Currency c ON m.Currency = c.Currency;

-- Restaurant Opening Trend (Number of restaurants opening based on Year, Quarter, Month)
SELECT cal.YearNo AS Year, cal.MonthFullName AS Month, cal.Quarter AS Quarter, cal.YearMonth AS YearMonth, cal.FinancialQuarter AS FinancialQuarter, 
COUNT(*) AS Restaurants_Opened FROM zomato_main m JOIN calendar cal ON cal.dt = m.Datekey_Opening
GROUP BY cal.YearNo, cal.MonthFullName, cal.Quarter, cal.YearMonth, cal.FinancialQuarter
ORDER BY cal.YearNo, cal.MonthFullName, cal.Quarter, cal.YearMonth, cal.FinancialQuarter;

-- Ratings Distribution
-- a. Count of Restaurants based on Ratings
SELECT Rating, COUNT(*) AS restaurants FROM zomato_main WHERE Rating IS NOT NULL GROUP BY Rating ORDER BY Rating DESC;

-- b. Count of Restaurants based on Ratings Bucket
SELECT CASE
    WHEN Rating < 1 THEN '0-1'
    WHEN Rating < 2 THEN '1-2'
    WHEN Rating < 3 THEN '2-3'
    WHEN Rating < 4 THEN '3-4'
    WHEN Rating <= 5 THEN '4-5'
    ELSE 'Unknown'
  END AS Rating_Bucket, COUNT(*) AS Restaurants
FROM zomato_main GROUP BY Rating_Bucket ORDER BY MIN(Rating) DESC;
-- Average Rating
SELECT ROUND(AVG(Rating),2) AS Avg_Rating FROM zomato_main;

-- Price buckets (based on Average_Cost_for_two and counts)
-- buckets on Local cost
SELECT CASE
    WHEN Average_Cost_for_two IS NULL THEN 'Unknown'
    WHEN Average_Cost_for_two <= 500 THEN '0-500'
    WHEN Average_Cost_for_two <= 1000 THEN '501-1000'
    WHEN Average_Cost_for_two <= 2000 THEN '1001-2000'
    WHEN Average_Cost_for_two <= 5000 THEN '2001-5000'
    ELSE '>5000'
  END AS Price_Bucket_Local, COUNT(*) AS Restaurants
FROM zomato_main GROUP BY Price_Bucket_Local ORDER BY FIELD(Price_Bucket_Local, '0-500','501-1000','1001-2000','2001-5000','>5000','Unknown');
-- buckets on USD (converted)
SELECT CASE
        WHEN usd_cost IS NULL THEN 'Unknown'
        WHEN usd_cost <= 7 THEN 'Cheap Eats'
        WHEN usd_cost <= 30 THEN 'Mid-Range'
        WHEN usd_cost <= 75 THEN 'Fine-Dining'
        ELSE 'Luxury'
    END AS Price_Bucket_USD, COUNT(*) AS Restaurants
FROM (SELECT m.Restaurant_ID, ROUND(m.Average_Cost_for_two * c.USD_Rate, 2) AS usd_cost FROM zomato_main m LEFT JOIN Currency c ON m.Currency = c.Currency) t
GROUP BY Price_Bucket_USD ORDER BY MIN(usd_cost);

-- Percentage of Restaurants based on Has_Table_booking
SELECT Has_Table_booking, COUNT(*) AS Restaurants, 
CONCAT(ROUND(100.0 * COUNT(DISTINCT Restaurant_ID) / (SELECT COUNT(DISTINCT Restaurant_ID) FROM zomato_main), 2), '%') AS Percentage
FROM zomato_main GROUP BY Has_Table_booking;

-- Percentage of Restaurants based on Has_Online_delivery
SELECT Has_Online_delivery, COUNT(*) AS Restaurants,
CONCAT(ROUND(100.0 * COUNT(DISTINCT Restaurant_ID) / (SELECT COUNT(DISTINCT Restaurant_ID) FROM zomato_main), 2), '%') AS Percentage
FROM zomato_main GROUP BY Has_Online_delivery;

-- Restaurants by Geography (Number of restaurants by City and Country)
SELECT Country, City, COUNT(*) AS Restaurants
FROM (SELECT COALESCE(ct.Country_Name, CAST(m.Country_Code AS CHAR)) AS Country, m.City FROM zomato_main m  LEFT JOIN country ct ON m.Country_Code = ct.Country_ID) t
GROUP BY Country, City ORDER BY Restaurants DESC LIMIT 500;

-- Cuisine Analysis (cuisine-city average rating and counts)
WITH RECURSIVE cuisine_split AS (
   SELECT m.Restaurant_ID, m.City, TRIM(SUBSTRING_INDEX(m.Cuisines, ',', 1)) AS cuisine, SUBSTRING(m.Cuisines, LENGTH(SUBSTRING_INDEX(m.Cuisines, ',', 1)) + 2) AS rest
   FROM zomato_main m WHERE m.Cuisines IS NOT NULL AND TRIM(m.Cuisines) <> ''
   UNION ALL
   SELECT cs.Restaurant_ID, cs.City, TRIM(SUBSTRING_INDEX(cs.rest, ',', 1)) AS cuisine, SUBSTRING(cs.rest, LENGTH(SUBSTRING_INDEX(cs.rest, ',', 1)) + 2) AS rest
   FROM cuisine_split cs WHERE cs.rest IS NOT NULL AND cs.rest <> ''
)
SELECT cs.City, cs.cuisine, COUNT(*) AS Restaurants, ROUND(AVG(m.Rating), 2) AS avg_rating, ROUND(AVG(m.Average_Cost_for_two * cur.USD_Rate), 2) AS avg_cost_usd
FROM cuisine_split cs JOIN zomato_main m ON m.Restaurant_ID = cs.Restaurant_ID LEFT JOIN Currency cur ON m.Currency = cur.Currency
GROUP BY cs.City, cs.cuisine ORDER BY cs.City, Restaurants DESC, avg_rating DESC LIMIT 200;

-- Top cuisines overall by avg rating
WITH RECURSIVE cuisine_split AS (
  SELECT m.Restaurant_ID, TRIM(SUBSTRING_INDEX(m.Cuisines, ',', 1)) AS cuisine, SUBSTRING(m.Cuisines, LENGTH(SUBSTRING_INDEX(m.Cuisines, ',', 1)) + 2) AS rest, 
  m.Rating FROM zomato_main m WHERE m.Cuisines IS NOT NULL AND TRIM(m.Cuisines) <> ''
  UNION ALL
  SELECT cs.Restaurant_ID, TRIM(SUBSTRING_INDEX(cs.rest, ',', 1)) AS cuisine, SUBSTRING(cs.rest, LENGTH(SUBSTRING_INDEX(cs.rest, ',', 1)) + 2), cs.Rating
  FROM cuisine_split cs WHERE cs.rest IS NOT NULL AND cs.rest <> '')
SELECT cuisine, COUNT(*) AS Restaurants, ROUND(AVG(Rating),2) AS avg_rating FROM cuisine_split WHERE cuisine IS NOT NULL AND cuisine <> ''
GROUP BY cuisine ORDER BY avg_rating DESC, Restaurants DESC LIMIT 10;

-- count restaurants per cuisine
WITH RECURSIVE cuisine_split AS (
  SELECT Restaurant_ID, TRIM(SUBSTRING_INDEX(Cuisines, ',', 1)) AS cuisine, TRIM(SUBSTR(Cuisines, LENGTH(SUBSTRING_INDEX(Cuisines, ',', 1)) + 2)) AS rest
  FROM zomato_main WHERE Cuisines IS NOT NULL AND TRIM(Cuisines) <> ''
  UNION ALL
  SELECT Restaurant_ID, TRIM(SUBSTRING_INDEX(rest, ',', 1)) AS cuisine, TRIM(SUBSTR(rest, LENGTH(SUBSTRING_INDEX(rest, ',', 1)) + 2)) AS rest
  FROM cuisine_split WHERE rest IS NOT NULL AND rest <> '')
SELECT cuisine AS Cuisine, COUNT(*) AS Restaurants FROM cuisine_split WHERE cuisine IS NOT NULL AND cuisine <> ''
GROUP BY cuisine ORDER BY Restaurants DESC LIMIT 300;






































