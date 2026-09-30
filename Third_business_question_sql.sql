WITH delivery_reviews AS (
    SELECT 
        o.order_id,
        r.review_score,
        o.order_delivered_customer_date - o.order_purchase_timestamp AS delivery_days,
        o.order_estimated_delivery_date,
        o.order_delivered_customer_date,
        CASE 
            WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date 
            THEN 'Late'
            ELSE 'On-time or Early'
        END AS delivery_status
    FROM orders o
    JOIN reviews r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp < '2018-09-01'
)

-- Part A: average review score by delivery speed bucket
SELECT 
    CASE 
        WHEN EXTRACT(DAY FROM delivery_days) <= 7 THEN '0-7 days'
        WHEN EXTRACT(DAY FROM delivery_days) <= 14 THEN '8-14 days'
        WHEN EXTRACT(DAY FROM delivery_days) <= 21 THEN '15-21 days'
        ELSE '22+ days'
    END AS delivery_bucket,
    COUNT(*) AS total_orders,
    ROUND(AVG(review_score), 2) AS avg_review_score
FROM delivery_reviews
GROUP BY delivery_bucket
ORDER BY MIN(EXTRACT(DAY FROM delivery_days));

-- Part B: on-time vs late delivery — average score comparison
WITH delivery_reviews AS (
    SELECT 
        o.order_id,
        r.review_score,
        CASE 
            WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date 
            THEN 'Late'
            ELSE 'On-time or Early'
        END AS delivery_status
    FROM orders o
    JOIN reviews r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp < '2018-09-01'
)
SELECT 
    delivery_status,
    COUNT(*) AS total_orders,
    ROUND(AVG(review_score), 2) AS avg_review_score
FROM delivery_reviews
GROUP BY delivery_status;