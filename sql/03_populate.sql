SET DEFINE OFF;
SET TIMING ON;

PROMPT 1/7: Populating Enhanced Airports...
INSERT INTO airports (airport_id, airport_code, city_name, state_abr, state_name, city_market_id)
SELECT 
    TO_NUMBER(origin_airport_id),
    origin,
    origin_city_name,
    origin_state_abr,
    origin_state_nm,
    TO_NUMBER(origin_city_market_id)
FROM ext_flight_raw WHERE origin_airport_id IS NOT NULL
UNION
SELECT 
    TO_NUMBER(dest_airport_id),
    dest,
    dest_city_name,
    dest_state_abr,
    dest_state_nm,
    TO_NUMBER(dest_city_market_id)
FROM ext_flight_raw WHERE dest_airport_id IS NOT NULL;
COMMIT;

PROMPT 2/7: Populating Airlines...
INSERT INTO airlines (carrier_code, airline_id, carrier_name)
SELECT DISTINCT op_unique_carrier, TO_NUMBER(op_carrier_airline_id), op_carrier
FROM ext_flight_raw
WHERE op_unique_carrier IS NOT NULL;
COMMIT;

PROMPT 3/7: Populating Aircraft Models and Fleet...
INSERT INTO aircraft_models VALUES (seq_model_id.NEXTVAL, 'B737-800', 'Boeing', 175, 'NARROW_BODY');
INSERT INTO aircraft_models VALUES (seq_model_id.NEXTVAL, 'A321-200', 'Airbus', 190, 'NARROW_BODY');
INSERT INTO aircraft_models VALUES (seq_model_id.NEXTVAL, 'CRJ-900',  'Bombardier', 76, 'REGIONAL');
COMMIT;

INSERT INTO aircraft_fleet (tail_num, carrier_code, model_id)
SELECT tail_num, op_unique_carrier,
       CASE WHEN op_unique_carrier IN ('WN', 'DL') THEN 1
            WHEN op_unique_carrier IN ('AA', 'B6') THEN 2
            ELSE 3 END AS model_id
FROM (
    SELECT tail_num, op_unique_carrier,
           ROW_NUMBER() OVER (PARTITION BY tail_num ORDER BY fl_date DESC) AS rn
    FROM ext_flight_raw
    WHERE tail_num IS NOT NULL AND op_unique_carrier IS NOT NULL
) WHERE rn = 1;
COMMIT;

PROMPT 4/7: Populating Flight Routes...
INSERT INTO flight_routes (route_id, origin_airport_id, dest_airport_id, distance_miles)
SELECT seq_route_id.NEXTVAL, origin_id, dest_id, dist
FROM (
    SELECT TO_NUMBER(origin_airport_id) AS origin_id, 
           TO_NUMBER(dest_airport_id) AS dest_id, 
           MAX(TO_NUMBER(distance)) AS dist
    FROM ext_flight_raw
    WHERE origin_airport_id IS NOT NULL AND dest_airport_id IS NOT NULL
      AND origin_airport_id <> dest_airport_id
    GROUP BY origin_airport_id, dest_airport_id
);
COMMIT;

PROMPT 5/7: Populating Flight Operations (631,970 rows)...
INSERT /*+ APPEND */ INTO flight_operations (
    flight_id, flight_date, carrier_code, flight_num, tail_num,
    route_id, crs_dep_time, dep_time, dep_delay_min,
    taxi_out_min, wheels_off, wheels_on, taxi_in_min,
    crs_arr_time, arr_time, arr_delay_min, cancelled, cancellation_code,
    diverted, crs_elapsed_time_min, actual_elapsed_time_min, air_time_min
)
SELECT 
    seq_flight_id.NEXTVAL,
    TO_DATE(SUBSTR(s.fl_date, 1, INSTR(s.fl_date, ' ') - 1), 'MM/DD/YYYY'),
    s.op_unique_carrier,
    TO_NUMBER(s.op_carrier_fl_num),
    s.tail_num,
    r.route_id,
    TO_NUMBER(s.crs_dep_time),
    TO_NUMBER(s.dep_time),
    NVL(TO_NUMBER(s.dep_delay), 0),
    NVL(TO_NUMBER(s.taxi_out), 0),
    TO_NUMBER(s.wheels_off),
    TO_NUMBER(s.wheels_on),
    NVL(TO_NUMBER(s.taxi_in), 0),
    TO_NUMBER(s.crs_arr_time),
    TO_NUMBER(s.arr_time),
    NVL(TO_NUMBER(s.arr_delay), 0),
    NVL(TO_NUMBER(s.cancelled), 0),
    s.cancellation_code,
    NVL(TO_NUMBER(s.diverted), 0),
    TO_NUMBER(s.crs_elapsed_time),
    TO_NUMBER(s.actual_elapsed_time),
    TO_NUMBER(s.air_time)
FROM ext_flight_raw s
JOIN flight_routes r 
  ON r.origin_airport_id = TO_NUMBER(s.origin_airport_id)
 AND r.dest_airport_id   = TO_NUMBER(s.dest_airport_id)
WHERE s.tail_num IS NULL 
   OR s.tail_num IN (SELECT tail_num FROM aircraft_fleet);
COMMIT;

PROMPT 6/7: Populating Delay Attributions (In-Memory Staging)...
CREATE TABLE stg_delayed AS
SELECT 
    TO_DATE(SUBSTR(fl_date, 1, INSTR(fl_date, ' ') - 1), 'MM/DD/YYYY') AS fl_date,
    op_unique_carrier AS carrier_code,
    TO_NUMBER(op_carrier_fl_num) AS flight_num,
    TO_NUMBER(crs_dep_time) AS crs_dep_time,
    NVL(tail_num, 'NONE') AS tail_num,
    NVL(TO_NUMBER(carrier_delay), 0) AS carrier_delay,
    NVL(TO_NUMBER(weather_delay), 0) AS weather_delay,
    NVL(TO_NUMBER(nas_delay), 0) AS nas_delay,
    NVL(TO_NUMBER(security_delay), 0) AS security_delay,
    NVL(TO_NUMBER(late_aircraft_delay), 0) AS late_ac_delay
FROM ext_flight_raw
WHERE TO_NUMBER(carrier_delay) > 0 OR TO_NUMBER(weather_delay) > 0 
   OR TO_NUMBER(nas_delay) > 0     OR TO_NUMBER(security_delay) > 0 
   OR TO_NUMBER(late_aircraft_delay) > 0;

INSERT /*+ APPEND */ INTO delay_attributions (
    flight_id, carrier_delay, weather_delay, nas_delay,
    security_delay, late_aircraft_delay
)
SELECT 
    flight_id, carrier_delay, weather_delay, nas_delay,
    security_delay, late_ac_delay
FROM (
    SELECT /*+ USE_HASH(f s) */
        f.flight_id,
        s.carrier_delay, s.weather_delay, s.nas_delay,
        s.security_delay, s.late_ac_delay,
        ROW_NUMBER() OVER (PARTITION BY f.flight_id ORDER BY s.carrier_delay DESC) AS rn
    FROM flight_operations f
    JOIN stg_delayed s
      ON f.flight_date   = s.fl_date
     AND f.carrier_code  = s.carrier_code
     AND f.flight_num    = s.flight_num
     AND f.crs_dep_time  = s.crs_dep_time
     AND NVL(f.tail_num, 'NONE') = s.tail_num
)
WHERE rn = 1;
COMMIT;
DROP TABLE stg_delayed PURGE;

PROMPT 7/7: Populating Flight Diversions and Gate Returns...
CREATE TABLE stg_diversions AS
SELECT 
    TO_DATE(SUBSTR(fl_date, 1, INSTR(fl_date, ' ') - 1), 'MM/DD/YYYY') AS fl_date,
    op_unique_carrier AS carrier_code,
    TO_NUMBER(op_carrier_fl_num) AS flight_num,
    TO_NUMBER(crs_dep_time) AS crs_dep_time,
    NVL(tail_num, 'NONE') AS tail_num,
    TO_NUMBER(first_dep_time) AS first_dep_time,
    TO_NUMBER(total_add_gtime) AS total_add_gtime,
    TO_NUMBER(longest_add_gtime) AS longest_add_gtime,
    TO_NUMBER(div_airport_landings) AS div_airport_landings,
    TO_NUMBER(div_reached_dest) AS div_reached_dest,
    TO_NUMBER(div_actual_elapsed_time) AS div_actual_elapsed_time,
    TO_NUMBER(div_arr_delay) AS div_arr_delay,
    TO_NUMBER(div_distance) AS div_distance,
    TRIM(REPLACE(REPLACE(div1_airport, CHR(13), ''), CHR(10), '')) AS div1_airport,
    TO_NUMBER(REGEXP_SUBSTR(div1_airport_id, '[0-9]+')) AS div1_airport_id
FROM ext_flight_raw
WHERE first_dep_time IS NOT NULL 
   OR (div_airport_landings IS NOT NULL AND TO_NUMBER(div_airport_landings) > 0)
   OR div1_airport IS NOT NULL;

INSERT /*+ APPEND */ INTO flight_diversions (
    flight_id, first_dep_time, total_add_gtime_min, longest_add_gtime_min,
    div_airport_landings, div_reached_dest, div_actual_elapsed_min,
    div_arr_delay_min, div_distance_miles, div1_airport_code, div1_airport_id
)
SELECT 
    flight_id, first_dep_time, total_add_gtime, longest_add_gtime,
    div_airport_landings, div_reached_dest, div_actual_elapsed_time,
    div_arr_delay, div_distance, div1_airport, div1_airport_id
FROM (
    SELECT /*+ USE_HASH(f s) */
        f.flight_id,
        s.first_dep_time, s.total_add_gtime, s.longest_add_gtime,
        s.div_airport_landings, s.div_reached_dest, s.div_actual_elapsed_time,
        s.div_arr_delay, s.div_distance, s.div1_airport, s.div1_airport_id,
        ROW_NUMBER() OVER (PARTITION BY f.flight_id ORDER BY s.div_airport_landings DESC NULLS LAST) AS rn
    FROM flight_operations f
    JOIN stg_diversions s
      ON f.flight_date   = s.fl_date
     AND f.carrier_code  = s.carrier_code
     AND f.flight_num    = s.flight_num
     AND f.crs_dep_time  = s.crs_dep_time
     AND NVL(f.tail_num, 'NONE') = s.tail_num
)
WHERE rn = 1;
COMMIT;
DROP TABLE stg_diversions PURGE;

SET TIMING OFF;
PROMPT Ingestion Pipeline Complete!