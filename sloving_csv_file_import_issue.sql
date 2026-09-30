-- Solving the csv file import issue through the below steps
-- STEP 1: Delete the old 5-column table structure entirely
DROP TABLE IF EXISTS olist_customers_5;

-- STEP 2: Create the fresh table with all 7 columns to match your CSV file
CREATE TABLE olist_customers_5 (
    review_id CHAR(32) NOT NULL,
    order_id CHAR(32) NOT NULL,
    review_score INT NOT NULL,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date TIMESTAMP,
    review_answer_timestamp TIMESTAMP,
    PRIMARY KEY (review_id, order_id)
);

-- STEP 3: Run the import command onto the brand new 7-column table
COPY olist_customers_5 (
    review_id, 
    order_id, 
    review_score, 
    review_comment_title, 
    review_comment_message,
    review_creation_date,
    review_answer_timestamp
)
FROM 'C:\Users\Public\olist_order_reviews_dataset.csv' 
WITH (
  FORMAT csv,
  HEADER true,
  QUOTE '"',
  ESCAPE '"',
  DELIMITER ','
);

SELECT * FROM olist_customers_5 limit 5





