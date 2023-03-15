#1.	Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.
select  distinct market from  dim_customer
where region='apac';


#2.	What is the percentage of unique product increase in 2021 vs. 2020? The final output contains these fields,unique_products_2020 unique_products_2021 percentage_chg

WITH 
  unique_products_2020 AS (
    SELECT 
      COUNT(DISTINCT product_code) AS count 
    FROM 
      fact_sales_monthly 
    WHERE 
      fiscal_year = 2020
  ),
  unique_products_2021 AS (
    SELECT 
      COUNT(DISTINCT product_code) AS count 
    FROM 
      fact_sales_monthly 
    WHERE 
      fiscal_year = 2021
  ),
  percentage_change AS (
    SELECT 
      (((unique_products_2021.count - unique_products_2020.count) / unique_products_2020.count) * 100) AS percentage_chng
    FROM 
      unique_products_2020, 
      unique_products_2021
  )
SELECT 
  unique_products_2020.count AS unique_products_2020, 
  unique_products_2021.count AS unique_products_2021, 
  percentage_change.percentage_chng
FROM 
  unique_products_2020, 
  unique_products_2021, 
  percentage_change;
  
  
#3.	Provide a report with all the unique product counts for each segment and sort them in descending order of product counts. The final output contains 2 fields,segment product_count
select segment, count(distinct product_code) as product_count
from dim_product
group by segment
order by product_count desc; 


#4.	Follow-up: Which segment had the most increase in unique products in 2021 vs 2020? The final output contains these fields,segment product_count_2020 product_count_2021 difference
with 
f_2020 as (
    select segment, product_code
    from dim_product
    join fact_sales_monthly using (product_code)
    where fiscal_year = 2020
),
f_2021 as (
    select segment, product_code
    from dim_product
    join fact_sales_monthly using (product_code)
    where fiscal_year = 2021
),
f_2020_agg as (
    select segment, count(distinct product_code) as product_count_2020
    from f_2020
    group by segment
),
f_2021_agg as (
    select segment, count(distinct product_code) as product_count_2021
    from f_2021
    group by segment
)
select 
	f_2020_agg.segment, 
    f_2020_agg.product_count_2020, 
    f_2021_agg.product_count_2021, 
    (f_2021_agg.product_count_2021 - f_2020_agg.product_count_2020) as difference
from f_2020_agg
join f_2021_agg using (segment)
order by difference desc;

#5.	Get the products that have the highest and lowest manufacturing costs. The final output should contain these fields,product_code product manufacturing_cost
SELECT product_code, product, manufacturing_cost 
FROM dim_product  
JOIN fact_manufacturing_cost USING (product_code)  
WHERE manufacturing_cost IN (  
    SELECT MAX(manufacturing_cost) FROM fact_manufacturing_cost  
    union
    SELECT MIN(manufacturing_cost) FROM fact_manufacturing_cost
);

#6.	Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct for the fiscal year 2021 and in the Indian market. The final output contains these fields,customer_code customer ,
SELECT
    dim_customer.customer_code,
    customer,
    round(((pre_invoice_discount_pct)*100), 2) AS average_discount_percentage
FROM
    fact_pre_invoice_deductions
    JOIN dim_customer ON fact_pre_invoice_deductions.customer_code = dim_customer.customer_code
WHERE
    fiscal_year = 2021
    AND market = 'India'
GROUP BY
    customer_code, customer
ORDER BY
    average_discount_percentage DESC
LIMIT 5;

#7.	Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month. This analysis helps to get an idea of low and high-performing months and take strategic decisions.The final report contains these columns:Month Year,Gross sales Amount
SELECT
	EXTRACT(MONTH FROM fact_sales_monthly.date) AS Month, 
    EXTRACT(YEAR FROM fact_sales_monthly.date) AS Year,
    ROUND(SUM((gross_price * sold_quantity)), 2) as gross_sales_amount
FROM fact_sales_monthly
JOIN dim_customer USING (customer_code)
JOIN fact_gross_price USING (product_code)
WHERE
  dim_customer.customer = 'Atliq Exclusive'
GROUP BY 
  Month, 
  Year
ORDER BY 
  Year ASC, 
  Month ASC;
  
#8.	In which quarter of 2020, got the maximum total_sold_quantity? The final output contains these fields sorted by the total_sold_quantity,Quarter total_sold_quantity 

WITH quarters AS (
  SELECT *,
         CASE
           WHEN MONTH(date) IN (9, 10, 11) THEN 'Q1'
           WHEN MONTH(date) IN (12, 1, 2) THEN 'Q2'
           WHEN MONTH(date) IN (3, 4, 5) THEN 'Q3'
           WHEN MONTH(date) IN (6, 7, 8) THEN 'Q4'
         END AS Quarter
  FROM fact_sales_monthly
  WHERE fiscal_year = 2020
)

SELECT Quarter, SUM(sold_quantity) AS total_sold_quantity
FROM quarters
GROUP BY Quarter
ORDER BY total_sold_quantity DESC;
#9.	Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution? The final output contains these fields,channel gross_sales_mln percentage
WITH channel_gross AS (
	SELECT 
		dim_customer.channel,
		ROUND(SUM(gross_price * sold_quantity), 2) AS gross_sales_mln
	FROM fact_sales_monthly
	JOIN dim_customer ON fact_sales_monthly.customer_code = dim_customer.customer_code
	JOIN fact_gross_price ON fact_sales_monthly.product_code = fact_gross_price.product_code
	WHERE fact_sales_monthly.fiscal_year = 2021
	GROUP BY dim_customer.channel
	ORDER BY gross_sales_mln DESC
)
SELECT 
	channel, 
	gross_sales_mln,
	ROUND((gross_sales_mln * 100 / sum(gross_sales_mln) over()), 3) AS percentage
FROM channel_gross;
#10.	Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021? The final output contains these fields,division product_code,product,total_sold_quantity rank_order
select division,product_code,product,total_sold_quantity,rnk  from
		(select division,product_code,product,total_sold_quantity,
		rank() over(partition by division order by total_sold_quantity desc) as rnk
		from (select p.product,p.product_code,p.division,sum(sm.sold_quantity)
		as total_sold_quantity from dim_product p join
		fact_sales_monthly sm on
		sm.product_code=p.product_code
		where sm.fiscal_year=2021
		group by p.product_code,p.division,p.product)x)y
		where rnk <=3