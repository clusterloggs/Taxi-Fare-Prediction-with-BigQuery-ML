# BigQuery ML: NYC Taxi Fare Prediction

This project serves as a rapid proof-of-concept (POC) demonstrating an end-to-end machine learning workflow within Google BigQuery. By leveraging BigQuery ML for fast prototyping, we can quickly build and evaluate a fare prediction model using only SQL before committing resources to a more complex production solution.

---

## 1. Project Overview

*   **Business Objective:** To provide customers with an accurate taxi fare estimate before their trip begins.
*   **Problem Statement:** Predict the total fare amount for a taxi ride in New York City using details available at the time of pickup, such as location coordinates and passenger count.
*   **Value Proposition:** By integrating this model into a customer-facing application, we can enhance user experience and build trust by providing transparent, upfront pricing.

---

## 2. BigQuery ML Implementation

*   **Dataset Source:** The project utilizes tables within the `taxirides` dataset in BigQuery.
*   **Features:** The model is trained on `euclidean` distance, `passenger_count`, and `trip_distance`.
*   **Target Variable:** The model predicts `fare_amount_356`, which is a combination of the base fare and any tolls.

---

## 3. SQL & BQML Workflow

This section documents each phase of the machine learning lifecycle with the actual SQL queries used.

### Phase 1: Data Preparation & Cleaning

First, we clean the raw historical data to create a reliable training set. The cleaned data is stored in a new table, `taxirides.taxi_training_data_753`.

```sql
CREATE OR REPLACE TABLE `taxirides.taxi_training_data_753` AS
SELECT
  -- useful features for prediction
  passenger_count,
  trip_distance,
  pickup_longitude AS pickuplon,
  pickup_latitude AS pickuplat,
  dropoff_longitude AS dropofflon,
  dropoff_latitude AS dropofflat,
  
  -- target variable
  (fare_amount + tolls_amount) AS fare_amount_356
FROM
  `taxirides.historical_taxi_rides_raw`
WHERE
  trip_distance > 4
  AND fare_amount >= 3
  AND passenger_count > 4
  AND pickup_latitude BETWEEN 40 AND 42
  AND dropoff_latitude BETWEEN 40 AND 42
  AND pickup_longitude BETWEEN -74.5 AND -72
  AND dropoff_longitude BETWEEN -74.5 AND -72
  AND MOD(ABS(FARM_FINGERPRINT(CAST(pickup_datetime AS STRING))), 1000) = 1;
```

---

### Phase 2: Model Training

Using the cleaned data, we train a linear regression model directly in BigQuery. The `CREATE MODEL` statement includes feature engineering to calculate the Euclidean distance from coordinates on the fly.

```sql
CREATE OR REPLACE MODEL `taxirides.fare_model_859`
OPTIONS(
  model_type = 'linear_reg',
  input_label_cols = ['fare_amount_356']
) AS
SELECT
  -- Feature engineering: calculate geographic distance
  ST_Distance(
    ST_GeogPoint(pickuplon, pickuplat),
    ST_GeogPoint(dropofflon, dropofflat)
  ) AS euclidean,
  -- Other features
  passenger_count,
  trip_distance,
  -- Label
  fare_amount_356
FROM
  `taxirides.taxi_training_data_753`;
```

- **Features:**
  - `euclidean` = geodesic distance between pickup and dropoff points
  - `passenger_count`
  - `trip_distance`
- **Target:** `fare_amount_356` (fare + tolls, excluding tips)

**Model Performance:**  
- RMSE ≈ **4.96** (requirement was ≤ 10)  
- MAE ≈ 3.23  

---

### 3. Batch Prediction
Prediction data (`report_prediction_data`) does not contain `trip_distance` or `passenger_count` (instead has `passengers`).  
We engineered missing features during prediction:

```sql
CREATE OR REPLACE TABLE `taxirides.2015_fare_amount_predictions` AS
SELECT *
FROM ML.PREDICT(
  MODEL `taxirides.fare_model_859`,
  (
    SELECT
      -- engineered euclidean distance
      ST_Distance(
        ST_GeogPoint(pickuplon, pickuplat),
        ST_GeogPoint(dropofflon, dropofflat)
      ) AS euclidean,

      -- rename passengers to match model input
      passengers AS passenger_count,

      -- approximate trip_distance (meters → miles)
      ST_Distance(
        ST_GeogPoint(pickuplon, pickuplat),
        ST_GeogPoint(dropofflon, dropofflat)
      ) / 1609.34 AS trip_distance
    FROM `taxirides.report_prediction_data`
  )
);
```

---

## Feature Engineering Notes

- **ST_GeogPoint(lon, lat):** Creates a geographic point from longitude/latitude.  
- **ST_Distance(pointA, pointB):** Returns geodesic distance in meters.  
- **Trip distance approximation:**
  \[
  \text{trip\_distance (miles)} = \frac{\text{ST\_Distance (meters)}}{1609.34}
  \]

This provides a proxy for meter-recorded `trip_distance` that is missing from prediction data.

---

## Results
- The model achieved **good accuracy** with RMSE ≈ 5.  
- Batch predictions were successfully stored in `2015_fare_amount_predictions`.  
- Leadership can now review results for potential app integration.

---

## Repository Structure
```
├── README.md                 # Project documentation
├── sql/
│   ├── 01_data_cleaning.sql  # SQL script for data cleaning
│   ├── 02_train_model.sql    # SQL script for BQML training
│   └── 03_batch_predict.sql  # SQL script for batch prediction
```

---

## How to Run
1. Open Google Cloud Console.  
2. Navigate to **BigQuery**.  
3. Run the SQL scripts in `/sql` in order.  
4. Verify model with:
   ```sql
   SELECT * FROM ML.EVALUATE(MODEL `taxirides.fare_model_859`);
   ```
5. Check predictions:
   ```sql
   SELECT * FROM `taxirides.2015_fare_amount_predictions` LIMIT 20;
   ```

---

## Key Learnings
- BigQuery ML enables fast prototyping without moving data.  
- Feature engineering (especially geospatial functions) is critical.  
- Prediction datasets often differ from training, so careful aliasing and feature creation are required.  
