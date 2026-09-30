# Data_analysis_project_1
# Olist E-Commerce Analysis: Why Did Revenue Growth Slow Down?

## The Problem

Olist is a Brazilian online marketplace that connects small sellers to
customers across the country. Looking at the order data, revenue grew
strongly through most of 2017 but flattened out in 2018. This project
digs into the order, payment, delivery, and review data to answer one
question: **why did growth slow down, and what should the business fix
first?**

I picked this dataset on purpose because it's messy and relational,
which is closer to real analyst work than a single clean spreadsheet.
There are 9 separate tables that need to be joined, cleaned, and
checked before any of the numbers can be trusted.

## Dataset

Brazilian E-Commerce Public Dataset by Olist, from Kaggle.
[Link to dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)

It covers about 100,000 real, anonymized orders placed on the Olist
platform between 2016 and 2018, spread across 9 CSV files:

- `orders` – order status and every timestamp in the order lifecycle
- `order_items` – each product in each order, with price and freight cost
- `order_payments` – how each order was paid, and how much
- `order_reviews` – customer review score and comments per order
- `customers` – customer location (state and city)
- `sellers` – seller location
- `products` – product category, weight, and dimensions
- `product_category_name_translation` – Portuguese category names
  translated to English
- `geolocation` – zip code to latitude/longitude lookup (not used in
  this analysis, more on that below)

## Tools Used

- **PostgreSQL** – loading the raw data, cleaning it, and writing every
  query used in the analysis
- **Power BI** – the dashboard, built directly on top of SQL views, not
  on raw tables

## Process

### 1. Loading the data

All 9 CSVs were loaded into PostgreSQL using `COPY`. One file,
`order_reviews`, failed on the first attempt because some customer
comments contained stray quote characters that broke the default CSV
parsing rules. Fixed by re-running `COPY` with explicit `QUOTE` and
`ESCAPE` settings so Postgres could handle the messy text fields
correctly.

### 2. Cleaning the data

Before writing any analysis queries, every table was checked for the
same five things: duplicate keys, missing values, wrong data types,
values that don't make logical sense, and inconsistent category names.
The full set of checks is in
[`olist_data_cleaning_checklist.sql`](./olist_data_cleaning_checklist.sql).

What actually came up during cleaning:

- **`orders` table:** a small number of orders marked "delivered" (24
  out of 96,478) were missing one or more of their delivery timestamps.
  Checked each case individually. Most were missing only the approval
  timestamp, which doesn't affect delivery time calculations. A
  smaller number were missing the actual delivery date, so those were
  excluded specifically from any query measuring delivery time, without
  removing them from the raw table.
- **`reviews` table:** grouping by `review_id` alone showed 789 values
  that looked duplicated. Turned out `review_id` is not a unique key on
  its own; the same review can legitimately be linked to more than one
  order. The real unique key is the combination of `review_id` and
  `order_id`. Noted this so every join to the reviews table uses
  `order_id`, not `review_id`.
- **`products` table:** 610 products had no category listed. Rather
  than drop them (which would make total revenue not match category-level
  revenue), they were grouped into an "Unknown category" bucket so
  every dollar of revenue is still counted somewhere.
- **Category name typo:** the category translation table had a
  misspelling, "costruction" instead of "construction", splitting what
  should have been one category into two. Fixed with a simple text
  replace before building the category ranking.
- **`geolocation` table:** checked for coordinates that fall outside
  Brazil's actual borders (some did, a handful had latitude/longitude
  values that would place them in Asia or North America). This table
  ended up not being used in the final dashboard, since none of the 5
  business questions needed a map. Left the cleaning notes in the
  checklist file in case it's used later.

### 3. Answering 5 business questions in SQL

Each question was written as its own SQL query (or view), building on
the cleaned tables. All queries are in the `/sql` folder.

1. What's the monthly revenue trend, and is it actually slowing down?
2. Which product categories bring in the most revenue?
3. Does delivery time affect how customers rate their orders?
4. Do customers come back and order again, and does that differ by state?
5. Do seller states differ in revenue and customer satisfaction?

### 4. Building the dashboard

Power BI connects directly to SQL views (not raw tables), so all of
the cleaning and business logic lives in SQL, and Power BI is only
responsible for displaying it. The dashboard has 3 pages, one KPI row
repeated at the top of each page, and a short written insight at the
bottom of every page explaining what the charts actually mean.

## Key Insights

### 1. Revenue grew strongly in 2017, then plateaued in 2018

Monthly revenue climbed from about $137K in January 2017 to a peak of
$1.17M in November 2017 (likely a Black Friday effect). After that,
from March through August 2018, revenue stayed roughly flat, moving
between $997K and $1.15M a month, with June 2018 showing the sharpest
single-month drop (-11%). Growth didn't collapse. It stopped.

*(Note: September–December 2016 and September 2018 were excluded from
this trend. The 2016 months only had 1 order each, likely platform
launch/testing activity. September 2018 also had just 1 order, which
means the dataset cuts off partway through that month.)*

### 2. A handful of categories drive most of the revenue

The top 5 categories, health & beauty, watches & gifts, bed/bath/table,
sports & leisure, and computers & accessories, bring in a large share
of total revenue. Some categories, like computers, have very few
orders but a very high value per order ($1,231 average), while others
like bed/bath/table have high order volume but a much lower value per
order. These are two different kinds of "good" categories and probably
need different strategies.

![Page 1 - Revenue Overview](./screenshots/page1_dashboard.png)
*Revenue trend and top categories. Revenue grows steadily through 2017 and plateaus in 2018.*

### 3. Late delivery has a big, clear effect on review scores

This is the strongest finding in the whole project. Orders delivered
on time or early got an average review score of **4.30**. Orders
delivered late got an average of **2.57**. That's a drop of about 1.7
points, on a 5-point scale, just from missing the delivery promise.

Looking at it by number of days: scores decline gently as delivery
takes longer, from 4.41 (0–7 days) down to 4.10 (15–21 days). But past
22 days, the average score drops sharply to 3.00. Delivery time matters,
but breaking the promised delivery date matters more.

About 8% of all orders were delivered late.

![Page 2 - Delivery & Satisfaction](./screenshots/page2_dashboard.png)
*The core finding: late orders score 2.57 vs 4.30 for on-time orders, and scores drop sharply after 22 days.*

### 4. Customers rarely come back, and it's not really a regional problem

Only about 3% of customers placed more than one order, and that number
is fairly consistent across every major state (2.9%–3.3% for the
biggest states by volume). A couple of states were a bit lower, CE at
1.6% and PE at 2.1%, but overall this looks like a platform-wide
loyalty issue rather than something specific to one region.

### 5. São Paulo dominates revenue, but has one of the lowest review scores

Sellers based in São Paulo (SP) generate roughly two-thirds of total
platform revenue, far more than any other state. But SP's average
review score is one of the lowest among states with meaningful order
volume, lower than smaller states like Rio Grande do Sul or Goiás.
Given the delivery time finding above, this is likely connected:
São Paulo's order volume probably means more logistics complexity and
more chances for something to arrive late.

![Page 3 - Regional Performance](./screenshots/page3_dashboard.png)
*São Paulo drives most of the revenue but has one of the lowest satisfaction scores, and repeat purchase rate is low almost everywhere.*

## Recommendations

1. **Treat late delivery as the top priority.** It has the clearest,
   largest effect on customer satisfaction of anything in this data.
   Orders on track to exceed 21 days should be flagged for priority
   handling before they cross that threshold, since that's where
   scores fall off a cliff.
2. **Consider more conservative delivery estimates at checkout.**
   Since a *late* order hurts satisfaction much more than a
   *long-but-accurate* one, giving customers a longer but reliable
   estimate may protect satisfaction better than promising a fast date
   and missing it.
3. **Invest in logistics specifically in São Paulo first.** It's the
   biggest market and currently has below-average satisfaction, so
   fixing delivery reliability there affects the most orders.
4. **Treat repeat-purchase as a platform-wide problem, not a regional
   one.** Since the ~3% repeat rate is consistent almost everywhere,
   a loyalty or retention program would likely help broadly rather
   than needing to target specific states.
5. **Clean up product category tagging.** 610 products (and a
   duplicate category caused by a typo) show that category data isn't
   fully reliable yet, worth fixing at the source before it affects
   more reporting down the line.

## Repo Structure

```
├── README.md
├── sql/
│   ├── olist_data_cleaning_checklist.sql
│   ├── 01_monthly_revenue_trend.sql
│   ├── 02_category_performance.sql
│   ├── 03_delivery_vs_reviews.sql
│   ├── 04_repeat_purchase_by_state.sql
│   └── 05_seller_region_performance.sql
├── dashboard/
│   └── olist_dashboard.pbix
└── screenshots/
    ├── page1_dashboard.png
    ├── page2_dashboard.png
    └── page3_dashboard.png
```

## Limitations

- The `geolocation` table wasn't used, since none of the 5 business
  questions needed a map. It's there if this project gets extended
  later.
- Review scores and delivery times are correlated, not proven to be
  causal. It's likely, based on how large and consistent the gap is,
  but this analysis doesn't rule out other factors happening at the
  same time.
- States with very few customers (under roughly 300) were excluded
  from the repeat-purchase chart, since their percentages aren't
  reliable at that sample size.

## Contact

[Your name] – [your email] – [LinkedIn link]
