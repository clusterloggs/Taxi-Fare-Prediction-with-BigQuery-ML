CREATE OR REPLACE TABLE `taxirides.taxi_training_data_753` AS
SELECT
  -- useful features for prediction
  pickup_datetime,
  dropoff_datetime,
  passenger_count,
  trip_distance,
  pickup_longitude,
  pickup_latitude,
  dropoff_longitude,
  dropoff_latitude,
  
  -- target variable
  (fare_amount + tolls_amount) AS fare_amount_356
FROM
  `taxirides.historical_taxi_rides_raw`
WHERE
  -- filters
  trip_distance > 4
  AND fare_amount >= 3
  AND passenger_count > 4
  AND pickup_latitude BETWEEN 40 AND 42
  AND dropoff_latitude BETWEEN 40 AND 42
  AND pickup_longitude BETWEEN -74.5 AND -72
  AND dropoff_longitude BETWEEN -74.5 AND -72
  
  -- sample down to < 1M rows
  AND MOD(ABS(FARM_FINGERPRINT(CAST(pickup_datetime AS STRING))), 1000) = 1
;
