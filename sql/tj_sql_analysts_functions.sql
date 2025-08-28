-- author: Tim Fateev

--How many unique product names (item_title) exist in Trader Joe’s price database?
SELECT  
    COUNT(DISTINCT sku) AS unique_skus,  
    COUNT(DISTINCT item_title) AS unique_product_names  
FROM product_prices;

--Identifying the Most Expensive and Cheapest Products Relative to the Average (with AVG and ROUND)
SELECT
    sku,
    item_title,
    ROUND(AVG(retail_price), 2) AS avg_price,
    ROUND(AVG(retail_price) - (SELECT AVG(retail_price) FROM product_prices), 2) AS diff_from_global_avg
FROM product_prices
WHERE retail_price IS NOT NULL
GROUP BY sku, item_title
ORDER BY diff_from_global_avg DESC
LIMIT 20;

--What is the contribution of each product to the overall pricing strategy? How much percent of the average price does each item represent (with OVER)?
SELECT
    sku,
    item_title,
    retail_price,
    ROUND(AVG(retail_price) OVER(), 2) AS avg_price,
    ROUND((retail_price / AVG(retail_price) OVER() * 100), 2) AS percent_of_avg_price,
    CASE
        WHEN (retail_price / AVG(retail_price) OVER() * 100) < 80 THEN 'Budget Segment'
        WHEN (retail_price / AVG(retail_price) OVER() * 100) BETWEEN 80 AND 120 THEN 'Standard Segment'
        ELSE 'Premium Segment'
    END AS price_segment
FROM product_prices
WHERE retail_price IS NOT NULL
LIMIT 20;

--How do prices in each Trader Joe’s store compare to the store’s own average price? Are there products priced significantly above or below the store-level average?
SELECT
    sku,
    item_title,
    store_code,
    retail_price,
    AVG(retail_price) OVER(PARTITION BY store_code) AS avg_price_by_store
FROM product_prices
WHERE retail_price IS NOT NULL
LIMIT 20;

--How do individual product prices deviate from the store-level average and from the SKU-level average within each store?
SELECT
    sku,
    item_title,
    store_code,
    retail_price,
    -- average price across the store
    ROUND(AVG(retail_price) OVER(PARTITION BY store_code), 2) AS avg_price_by_store,
    -- average price for the SKU within the store
    ROUND(AVG(retail_price) OVER(PARTITION BY store_code, sku), 2) AS avg_price_by_store_and_sku,
    -- deviation from store-level average
    ROUND(retail_price - AVG(retail_price) OVER(PARTITION BY store_code), 2) AS store_delta,
    -- deviation from SKU-level average inside the store
    ROUND(retail_price - AVG(retail_price) OVER(PARTITION BY store_code, sku), 2) AS store_and_sku_delta
FROM product_prices
WHERE retail_price IS NOT NULL
LIMIT 20;

--Which products are the most expensive in Trader Joe’s assortment when ranked in descending order by price?
SELECT
    sku,
    item_title,
    store_code,
    retail_price,
    ROW_NUMBER() OVER(ORDER BY retail_price DESC) AS overall_price_rank
FROM product_prices
WHERE retail_price IS NOT NULL
LIMIT 20;

--Which products are the top 3 most expensive items in each Trader Joe’s store?
WITH latest_price AS (
    SELECT
        sku,
        item_title,
        store_code,
        retail_price,
        ROW_NUMBER() OVER(PARTITION BY item_title ORDER BY inserted_at DESC) AS rn
    FROM product_prices
    WHERE retail_price IS NOT NULL
),
ranked AS (
    SELECT
        sku,
        item_title,
        store_code,
        retail_price,
        ROW_NUMBER() OVER(PARTITION BY store_code ORDER BY retail_price DESC) AS store_price_rank
    FROM latest_price
    WHERE rn = 1
)
SELECT *
FROM ranked
WHERE store_price_rank <= 3
ORDER BY store_code, store_price_rank;

--Ranking products globally and within each Trader Joe’s store
--SQL Solution - This query ranks Trader Joe’s products both globally and within each store based on --their price, comparing the difference between ROW_NUMBER() and RANK() window functions.
SELECT
    sku,
    item_title,
    store_code,
    retail_price,
    -- Global ranking by price (every row gets a unique rank, even with duplicate prices)
    ROW_NUMBER() OVER(ORDER BY retail_price DESC) AS overall_price_rank,
    -- Global ranking by price (same prices share the same rank)
    RANK() OVER(ORDER BY retail_price DESC) AS overall_price_rank_with_rank,
    -- Ranking within each store (unique per row)
    ROW_NUMBER() OVER(PARTITION BY store_code ORDER BY retail_price DESC) AS store_price_rank,
    -- Ranking within each store (same prices share the same rank)
    RANK() OVER(PARTITION BY store_code ORDER BY retail_price DESC) AS store_price_rank_with_rank
FROM product_prices
WHERE retail_price IS NOT NULL
LIMIT 20;

--Comparing Ranking Functions with DENSE_RANK
SELECT
    sku,
    item_title,
    store_code,
    retail_price,
    -- Strict row numbering (every row is unique, even if price repeats)
    ROW_NUMBER() OVER(ORDER BY retail_price DESC) AS overall_price_row_number,
    -- Ranking with gaps (ties share rank, but next rank is skipped)
    RANK() OVER(ORDER BY retail_price DESC) AS overall_price_rank,
    -- Dense ranking (ties share rank, no gaps in numbering)
    DENSE_RANK() OVER(ORDER BY retail_price DESC) AS overall_price_dense_rank
FROM product_prices
WHERE retail_price IS NOT NULL
LIMIT 20;

--How has the price of Beef Filet Mignon Steak changed over time across different Trader Joe’s stores?
WITH price_changes AS (
    SELECT
        sku,
        item_title,
        store_code,
        retail_price,
        inserted_at,
        LAG(retail_price) OVER(PARTITION BY sku, store_code ORDER BY inserted_at) AS previous_price,
        (retail_price - LAG(retail_price) OVER(PARTITION BY sku, store_code ORDER BY inserted_at)) AS price_change
    FROM product_prices
    WHERE item_title = 'Beef Filet Mignon Steak'
      AND retail_price IS NOT NULL
)
SELECT *
FROM price_changes
WHERE price_change IS DISTINCT FROM 0
ORDER BY store_code, inserted_at;

--Forecasting Next Price with LEAD
WITH price_changes AS (
    SELECT
        sku,
        item_title,
        store_code,
        retail_price,
        MIN(inserted_at) AS inserted_at
    FROM product_prices
    WHERE item_title = 'Toscano Cheese with Black Pepper'
      AND retail_price IS NOT NULL
    GROUP BY sku, item_title, store_code, retail_price
),
ranked AS (
    SELECT
        sku,
        item_title,
        store_code,
        retail_price,
        inserted_at,
        LEAD(retail_price) OVER(PARTITION BY sku, store_code ORDER BY inserted_at) AS next_price
    FROM price_changes
)
SELECT *
FROM ranked
ORDER BY store_code, inserted_at;