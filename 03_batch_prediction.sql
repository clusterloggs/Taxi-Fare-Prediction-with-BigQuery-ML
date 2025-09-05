CREATE OR REPLACE TABLE `taxirides.2015_fare_amount_predictions` AS
SELECT *
FROM ML.PREDICT(
  MODEL `taxirides.fare_model_859`,
  (
    SELECT
      -- engineered feature
      ST_Distance(
        ST_GeogPoint(pickuplon, pickuplat),
        ST_GeogPoint(dropofflon, dropofflat)
      ) AS euclidean,

      -- rename passengers to match model input
      passengers AS passenger_count,

      -- approximate trip_distance using ST_Distance (convert from meters to miles if needed)
      ST_Distance(
        ST_GeogPoint(pickuplon, pickuplat),
        ST_GeogPoint(dropofflon, dropofflat)
      ) / 1609.34 AS trip_distance

    FROM `qwiklabs-gcp-04-e5051c22c86c.taxirides.report_prediction_data`
  )
);
