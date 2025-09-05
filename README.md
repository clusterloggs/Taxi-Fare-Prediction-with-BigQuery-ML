# Taxi Fare Prediction with BigQuery ML

This project is based on the **Engineer Data for Predictive Modeling with BigQuery ML** Qwiklabs challenge.  
The goal is to clean historical taxi ride data, build a fare prediction model using **BigQuery ML**, and run batch predictions for unseen data.

---

## Project Overview
- **Objective:** Predict taxi fares based on ride details available at the start of a trip.  
- **Dataset:** Historical NYC taxi rides (`historical_taxi_rides_raw`) and prediction data (`report_prediction_data`).  
- **Model:** Linear regression built with BigQuery ML.  
- **Output:** Predicted fares stored in a new table `2015_fare_amount_predictions`.

---

## Steps Performed

### 1. Data Cleaning
We cleaned the raw dataset (`historical_taxi_rides_raw`) and stored the result in:
```
taxirides.taxi_training_data_753
```

Cleaning rules included:
- Keep only trips with:
  - `trip_distance > 4`
  - `fare_amount >= 3`
  - `passenger_count > 4`
- Restrict lat/lon to reasonable NYC ranges:
  ```sql
  pickuplat BETWEEN 40 AND 42
  pickuplon BETWEEN -74.5 AND -72
  dropofflat BETWEEN 40 AND 42
  dropofflon BETWEEN -74.5 AND -72
  ```
- Construct target variable:
  ```sql
  fare_amount_356 = fare_amount + tolls_amount
  ```
- Sample to < 1M rows using:
  ```sql
  AND MOD(ABS(FARM_FINGERPRINT(CAST(pickup_datetime AS STRING))), 1000) = 1
  ```

---

### 2. Model Training
We trained a linear regression model in BigQuery ML:

```sql
CREATE OR REPLACE MODEL `taxirides.fare_model_859`
OPTIONS(
  model_type = 'linear_reg',
  input_label_cols = ['fare_amount_356']
) AS
SELECT
  ST_Distance(
    ST_GeogPoint(pickuplon, pickuplat),
    ST_GeogPoint(dropofflon, dropofflat)
  ) AS euclidean,
  passenger_count,
  trip_distance,
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
