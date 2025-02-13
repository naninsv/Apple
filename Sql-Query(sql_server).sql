-- Apple Sales Project - 1M rows Sales dataset

select * from category;
select * from Products;
select* from stores;
select * from sales;
select * from warranty;
 -- Adding Foreign Key Constraints

-- products -> category
ALTER TABLE products  
ADD CONSTRAINT fk_products_category  
FOREIGN KEY (category_id) REFERENCES category(category_id);

-- sales -> stores
ALTER TABLE sales  
ADD CONSTRAINT fk_sales_stores  
FOREIGN KEY (store_id) REFERENCES stores(store_id);

-- sales -> products
ALTER TABLE sales  
ADD CONSTRAINT fk_sales_products  
FOREIGN KEY (product_id) REFERENCES products(product_id);

-- warranty -> sales
ALTER TABLE warranty  
ADD CONSTRAINT fk_warranty_sales  
FOREIGN KEY (sale_id) REFERENCES sales(sale_id);


-- Improving Query Performance

CREATE INDEX sales_product_id on sales(product_id);
CREATE INDEX sales_store_id on sales(store_id);

-- 1.Find each country and number of stores
select country, count(store_id) as Total_Stores
from stores
Group by country
order by Total_Stores desc;

-- What is the total number of units sold by each store?
select 
st.store_id,
st.store_name,
sum(quantity) as total_units
from sales sl inner join stores st
on st.store_id = sl.store_id
Group by st.store_id,st.store_name
order by total_units Desc;
-- or group by 1,2
--order by 3

SELECT COUNT(sale_id) AS total_sales
FROM sales
WHERE MONTH(sale_date) = 12 AND YEAR(sale_date) = 2023;

SELECT *,
       FORMAT(sale_date, 'MM-yyyy') AS formatted_date
FROM sales
WHERE FORMAT(sale_date, 'MM-yyyy') = '12-2023';

-- 4 How many stores have never had a warranty claim filed against any of their products?
  select * from stores
-- recieved warranty claims stores

select count(*) as total_stores_not_claimed_warranty from stores
where store_id NOT IN(
 						select 
 						distinct(store_id)
 						--store_id
 						from warranty w left join sales s
 						on w.sale_id = s.sale_id);-- recieved warranty claims stores

-- 5. What percentage of warranty claims are marked as "Warranty Void"?
SELECT 
    ROUND(
        (COUNT(claim_id) * 100.0) / (SELECT COUNT(*) FROM warranty), 2
    ) AS warranty_void_percentage
FROM warranty
WHERE repair_status = 'Warranty Void';

-- 6. Which store had the highest total units sold in the last year?
select * from sales

SELECT TOP 1 
    store_id, 
    SUM(quantity) AS total_units_sold
FROM sales
WHERE sale_date > DATEADD(YEAR, -1, GETDATE())  -- Last 1 year
GROUP BY store_id
ORDER BY total_units_sold DESC;

-- 7. Count the number of unique products sold in the last year.
select * from sales;

SELECT 
    COUNT(DISTINCT product_id) AS unique_products
FROM sales
WHERE sale_date >= DATEADD(YEAR, -1, GETDATE());  -- Last 1 year

--8. What is the average price of products in each category?
SELECT
    c.category_id,
    c.category_name,
    ROUND(AVG(p.price), 2) AS average_price  -- Rounding to 2 decimal places
FROM products p
JOIN category c  -- Fixed table alias from 'cs' to 'c'
ON p.category_id = c.category_id
GROUP BY c.category_id, c.category_name  -- Added c.category_name for proper grouping
ORDER BY average_price DESC;


--How many warranty claims were filed in 2020?
SELECT 
    COUNT(claim_id) AS warranty_claims
FROM warranty
WHERE YEAR(claim_date) = 2020;

-- Identify each store and best selling day based on highest qty sold
WITH RankedSales AS (
    SELECT 
        store_id,
        FORMAT(sale_date, 'dddd') AS day_name,  -- Converts date to full day name
        SUM(quantity) AS total_unit_sold,
        RANK() OVER (PARTITION BY store_id ORDER BY SUM(quantity) DESC) AS rank
    FROM sales
    GROUP BY store_id, FORMAT(sale_date, 'dddd')
)
SELECT store_id, day_name, total_unit_sold
FROM RankedSales
WHERE rank = 1;


--Identify least selling product of each country for each year based on total unit sold
WITH product_rank AS (
    SELECT
        st.country,
        p.product_name,
        YEAR(sl.sale_date) AS year,  -- Extracts the year from the date
        SUM(sl.quantity) AS total_quantity_sold,
        RANK() OVER (
            PARTITION BY st.country, YEAR(sl.sale_date) 
            ORDER BY SUM(sl.quantity) ASC  -- ASC for least-selling product
        ) AS rank
    FROM stores st
    JOIN sales sl ON st.store_id = sl.store_id
    JOIN products p ON p.product_id = sl.product_id
    GROUP BY st.country, p.product_name, YEAR(sl.sale_date)
)
SELECT *
FROM product_rank
WHERE rank = 1;

-- 12. How many warranty claims were filed within 180 days of a product sale?

SELECT 
    w.*, 
    s.sale_date, 
    w.claim_date,
    DATEDIFF(DAY, s.sale_date, w.claim_date) AS claim_days
FROM warranty w 
LEFT JOIN sales s ON s.sale_id = w.sale_id
WHERE DATEDIFF(DAY, s.sale_date, w.claim_date) <= 180;


-- 13. How many warranty claims have been filed for products launched in the last two years?

SELECT
    p.product_id,
    p.product_name,
    p.launch_date,
    COUNT(w.claim_id) AS claims
FROM warranty w
JOIN sales s ON s.sale_id = w.sale_id
JOIN products p ON p.product_id = s.product_id
WHERE p.launch_date >= DATEADD(YEAR, -2, GETDATE())  -- Products launched in the last 2 years
GROUP BY p.product_id, p.product_name, p.launch_date;




-- 14 List the months in the last three years where sales exceeded 5,000 units in the USA.
 
SELECT 
    FORMAT(s.sale_date, 'MM-yyyy') AS month,
    SUM(s.quantity) AS Total_sales
FROM sales AS s
JOIN stores AS st ON s.store_id = st.store_id
WHERE 
    st.country = 'USA'
    AND s.sale_date >= DATEADD(YEAR, -3, GETDATE())  -- Sales in the last 3 years
GROUP BY FORMAT(s.sale_date, 'MM-yyyy')
HAVING SUM(s.quantity) > 5000;

-- Q.15 Identify the product category with the most warranty claims filed in the last two years.
SELECT 
    c.category_name,
    COUNT(w.claim_id) AS total_claims	
FROM warranty AS w
LEFT JOIN sales AS s ON w.sale_id = s.sale_id
JOIN products AS p ON s.product_id = p.product_id
JOIN category AS c ON p.category_id = c.category_id
WHERE 
    w.claim_date >= DATEADD(YEAR, -2, GETDATE())  -- Last 2 years
GROUP BY c.category_name
ORDER BY total_claims DESC;  -- Optional: Sort by highest claims


-- Complex Problems
-- Q.16 Determine the percentage chance of receiving warranty claims after each purchase for each country!
SELECT 
    country,
    total_sales,
    total_claims,
    ROUND(ISNULL(CAST(total_claims AS FLOAT) / NULLIF(CAST(total_sales AS FLOAT), 0) * 100, 0), 2) 
    AS percentage_warranty_claims
FROM
(
    SELECT 
        st.country,
        SUM(s.quantity) AS total_sales,
        COUNT(w.claim_id) AS total_claims
    FROM sales AS s
    JOIN stores AS st ON s.store_id = st.store_id
    LEFT JOIN warranty AS w ON s.sale_id = w.sale_id
    GROUP BY st.country
) t1
ORDER BY percentage_warranty_claims DESC;


-- Q.17 Analyze the year-by-year growth ratio for each store.
WITH yearly_sales AS (
    SELECT 
        st.store_id,
        st.store_name,
        YEAR(s.sale_date) AS year,
        SUM(p.price * s.quantity) AS total_sale
    FROM sales AS s
    JOIN products AS p ON s.product_id = p.product_id
    JOIN stores AS st ON s.store_id = st.store_id
    GROUP BY st.store_id, st.store_name, YEAR(s.sale_date)
),

Growth_Ratio AS (
    SELECT
        store_name,
        year,
        LAG(total_sale, 1) OVER (PARTITION BY store_name ORDER BY year) AS last_year_sale,
        total_sale AS current_year_sale
    FROM yearly_sales
)

SELECT 
    store_name,
    year,
    last_year_sale,
    current_year_sale,
    ROUND(
        (CAST(current_year_sale AS FLOAT) - CAST(last_year_sale AS FLOAT)) / 
        NULLIF(CAST(last_year_sale AS FLOAT), 0) * 100, 3
    ) AS growth_ratio
FROM Growth_Ratio
WHERE last_year_sale IS NOT NULL
AND year <> YEAR(GETDATE());  -- Exclude the current year

-- Q.18 Calculate the correlation between product price and warranty claims for 
-- products sold in the last five years, segmented by price range.

SELECT
    CASE 
        WHEN p.price < 500 THEN 'LESS EXPENSIVE PRODUCT'
        WHEN p.price BETWEEN 500 AND 1000 THEN 'MID RANGE PRODUCT'
        ELSE 'EXPENSIVE PRODUCT'
    END AS price_Segment,
    COUNT(w.claim_id) AS Total_claims
FROM warranty AS w
LEFT JOIN sales AS s ON w.sale_id = s.sale_id
JOIN products AS p ON p.product_id = s.product_id
WHERE w.claim_date >= DATEADD(YEAR, -5, GETDATE())  -- Adjusted for SQL Server
GROUP BY 
    CASE 
        WHEN p.price < 500 THEN 'LESS EXPENSIVE PRODUCT'
        WHEN p.price BETWEEN 500 AND 1000 THEN 'MID RANGE PRODUCT'
        ELSE 'EXPENSIVE PRODUCT'
    END
ORDER BY Total_claims DESC;


-- Q.19 Identify the store with the highest percentage of "Paid Repaired" claims relative to total claims filed
WITH paid_repair AS (
    SELECT 
        s.store_id,
        COUNT(w.claim_id) AS paid_repaired
    FROM sales AS s
    LEFT JOIN warranty AS w ON s.sale_id = w.sale_id
    WHERE w.repair_status = 'Paid Repaired'
    GROUP BY s.store_id
),

total_repaired AS (
    SELECT 
        s.store_id,
        COUNT(w.claim_id) AS total_repaired
    FROM sales AS s
    LEFT JOIN warranty AS w ON s.sale_id = w.sale_id
    GROUP BY s.store_id
)

SELECT 
    tr.store_id,
    st.store_name,
    pr.paid_repaired,
    tr.total_repaired,
    ROUND(CAST(pr.paid_repaired AS FLOAT) / CAST(tr.total_repaired AS FLOAT) * 100,2) AS percentage_paid_repaired
FROM total_repaired AS tr
JOIN paid_repair AS pr ON pr.store_id = tr.store_id
JOIN stores AS st ON st.store_id = tr.store_id
ORDER BY percentage_paid_repaired DESC;


-- -- Q.20 Write a query to calculate the monthly running total of sales for each store
-- over the past four years and compare trends during this period.

WITH monthly_sales AS (
    SELECT
        s.store_id,
        YEAR(s.sale_date) AS year,
        MONTH(s.sale_date) AS month,
        SUM(p.price * s.quantity) AS total_revenue
    FROM sales AS s
    JOIN products AS p ON p.product_id = s.product_id
    WHERE s.sale_date >= DATEADD(YEAR, -4, GETDATE()) -- Last 4 years
    GROUP BY s.store_id, YEAR(s.sale_date), MONTH(s.sale_date)
)

SELECT 
    store_id,
    year,
    month,
    total_revenue,
    SUM(total_revenue) OVER(PARTITION BY store_id ORDER BY year, month) AS running_total
FROM monthly_sales
ORDER BY store_id, year, month;
























