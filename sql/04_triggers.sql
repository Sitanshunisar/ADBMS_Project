SET DEFINE OFF;
SET SERVEROUTPUT ON;
SPOOL C:\database_project\data\04_triggers_output.txt;

PROMPT ================================================================
PROMPT 1. Creating Triggers
PROMPT ================================================================

-- Trigger 1: Automatic 3-Hour DOT Tarmac Rule Compliance Auditor
CREATE OR REPLACE TRIGGER trg_audit_tarmac_delay
AFTER INSERT OR UPDATE OF taxi_out_min, taxi_in_min ON flight_operations
FOR EACH ROW
BEGIN
    -- Departure taxi delay breach (> 180 min)
    IF :NEW.taxi_out_min > 180 THEN
        INSERT INTO regulatory_violations (
            violation_id, flight_id, violation_type, metric_value_min, fine_assessed_usd, notes
        ) VALUES (
            seq_violation_id.NEXTVAL,
            :NEW.flight_id,
            'TARMAC_DEPARTURE_EXCEEDED',
            :NEW.taxi_out_min,
            ROUND(27500 + ((:NEW.taxi_out_min - 180) * 250), 2),
            'DOT 3-Hour Rule breach (Departure): Carrier ' || :NEW.carrier_code || ', Flight ' || :NEW.flight_num
        );
    END IF;

    -- Arrival taxi delay breach (> 180 min)
    IF :NEW.taxi_in_min > 180 THEN
        INSERT INTO regulatory_violations (
            violation_id, flight_id, violation_type, metric_value_min, fine_assessed_usd, notes
        ) VALUES (
            seq_violation_id.NEXTVAL,
            :NEW.flight_id,
            'TARMAC_ARRIVAL_EXCEEDED',
            :NEW.taxi_in_min,
            ROUND(27500 + ((:NEW.taxi_in_min - 180) * 250), 2),
            'DOT 3-Hour Rule breach (Arrival): Carrier ' || :NEW.carrier_code || ', Flight ' || :NEW.flight_num
        );
    END IF;
END;
/
SHOW ERRORS TRIGGER trg_audit_tarmac_delay;

-- Trigger 2: Domain Integrity Check for Delay Attributions
CREATE OR REPLACE TRIGGER trg_validate_delay_attribution
BEFORE INSERT OR UPDATE ON delay_attributions
FOR EACH ROW
BEGIN
    IF :NEW.carrier_delay < 0 OR :NEW.weather_delay < 0 OR
       :NEW.nas_delay < 0     OR :NEW.security_delay < 0 OR
       :NEW.late_aircraft_delay < 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Delay attribution values cannot be negative.');
    END IF;
END;
/
SHOW ERRORS TRIGGER trg_validate_delay_attribution;

-- Trigger 3: Cancellation Logical Consistency Auditor
CREATE OR REPLACE TRIGGER trg_validate_cancellation
BEFORE INSERT OR UPDATE OF cancelled, cancellation_code, air_time_min ON flight_operations
FOR EACH ROW
BEGIN
    -- If marked cancelled, air time must be null or 0
    IF :NEW.cancelled = 1 AND NVL(:NEW.air_time_min, 0) > 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Cancelled flight cannot record positive air time minutes.');
    END IF;

    -- If marked cancelled, code must be one of DOT standards: A (Carrier), B (Weather), C (NAS), D (Security)
    IF :NEW.cancelled = 1 AND :NEW.cancellation_code IS NOT NULL 
       AND :NEW.cancellation_code NOT IN ('A', 'B', 'C', 'D') THEN
        RAISE_APPLICATION_ERROR(-20003, 'Invalid DOT cancellation code. Must be A, B, C, or D.');
    END IF;
END;
/
SHOW ERRORS TRIGGER trg_validate_cancellation;


PROMPT ================================================================
PROMPT 2. Creating Stored Procedures
PROMPT ================================================================

-- Stored Procedure 1: Comprehensive Carrier Performance Audit
CREATE OR REPLACE PROCEDURE sp_carrier_performance_audit (
    p_carrier_code IN VARCHAR2
) AS
    v_carrier_name      VARCHAR2(100);
    v_total_flights     NUMBER;
    v_cancelled_flights NUMBER;
    v_diverted_flights  NUMBER;
    v_avg_arr_delay     NUMBER;
    v_ontime_pct        NUMBER;
BEGIN
    SELECT carrier_name INTO v_carrier_name 
    FROM airlines 
    WHERE carrier_code = p_carrier_code;

    SELECT 
        COUNT(flight_id),
        SUM(cancelled),
        SUM(diverted),
        ROUND(AVG(arr_delay_min), 2),
        ROUND(100 * (1 - (SUM(CASE WHEN arr_delay_min > 15 OR cancelled = 1 THEN 1 ELSE 0 END) / COUNT(flight_id))), 2)
    INTO 
        v_total_flights,
        v_cancelled_flights,
        v_diverted_flights,
        v_avg_arr_delay,
        v_ontime_pct
    FROM flight_operations
    WHERE carrier_code = p_carrier_code;

    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE(' CARRIER OPERATIONAL AUDIT: ' || v_carrier_name || ' (' || p_carrier_code || ')');
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('Total Flights Tracked   : ' || TO_CHAR(v_total_flights, '999,999'));
    DBMS_OUTPUT.PUT_LINE('Cancelled Flights       : ' || TO_CHAR(v_cancelled_flights, '999,999'));
    DBMS_OUTPUT.PUT_LINE('Diverted Flights        : ' || TO_CHAR(v_diverted_flights, '999,999'));
    DBMS_OUTPUT.PUT_LINE('Average Arrival Delay   : ' || v_avg_arr_delay || ' mins');
    DBMS_OUTPUT.PUT_LINE('DOT A14 On-Time Rate    : ' || v_ontime_pct || '%');
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Error: Carrier code "' || p_carrier_code || '" not found.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Execution Error: ' || SQLERRM);
END;
/
SHOW ERRORS PROCEDURE sp_carrier_performance_audit;

-- Stored Procedure 2: Corridor & Route Congestion Analyzer
CREATE OR REPLACE PROCEDURE sp_route_congestion_analyzer (
    p_origin_code IN VARCHAR2,
    p_dest_code   IN VARCHAR2
) AS
    v_route_id         NUMBER;
    v_distance         NUMBER;
    v_flight_count     NUMBER;
    v_avg_dep_delay    NUMBER;
    v_avg_arr_delay    NUMBER;
    v_avg_taxi_out     NUMBER;
BEGIN
    SELECT r.route_id, r.distance_miles
    INTO v_route_id, v_distance
    FROM flight_routes r
    JOIN airports o ON o.airport_id = r.origin_airport_id
    JOIN airports d ON d.airport_id = r.dest_airport_id
    WHERE o.airport_code = p_origin_code AND d.airport_code = p_dest_code;

    SELECT 
        COUNT(flight_id),
        ROUND(AVG(dep_delay_min), 2),
        ROUND(AVG(arr_delay_min), 2),
        ROUND(AVG(taxi_out_min), 2)
    INTO 
        v_flight_count,
        v_avg_dep_delay,
        v_avg_arr_delay,
        v_avg_taxi_out
    FROM flight_operations
    WHERE route_id = v_route_id;

    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE(' ROUTE CONGESTION REPORT: ' || p_origin_code || ' -> ' || p_dest_code);
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('Distance               : ' || v_distance || ' miles');
    DBMS_OUTPUT.PUT_LINE('Total Flights Flown    : ' || v_flight_count);
    DBMS_OUTPUT.PUT_LINE('Average Departure Delay: ' || v_avg_dep_delay || ' mins');
    DBMS_OUTPUT.PUT_LINE('Average Arrival Delay  : ' || v_avg_arr_delay || ' mins');
    DBMS_OUTPUT.PUT_LINE('Average Taxi-Out Time  : ' || v_avg_taxi_out || ' mins');
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Route between ' || p_origin_code || ' and ' || p_dest_code || ' does not exist in registry.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Execution Error: ' || SQLERRM);
END;
/
SHOW ERRORS PROCEDURE sp_route_congestion_analyzer;


PROMPT ================================================================
PROMPT 3. Executing Historical Audit & Stored Procedure Tests
PROMPT ================================================================

PROMPT Auditing existing flight records for historical tarmac breaches...
INSERT INTO regulatory_violations (
    violation_id, flight_id, violation_type, metric_value_min, fine_assessed_usd, notes
)
SELECT 
    seq_violation_id.NEXTVAL,
    flight_id,
    violation_type,
    metric_value,
    ROUND(27500 + ((metric_value - 180) * 250), 2),
    'Historical DOT Tarmac Rule breach: ' || carrier_code || '-' || flight_num
FROM (
    SELECT flight_id, carrier_code, flight_num, 'TARMAC_DEPARTURE_EXCEEDED' AS violation_type, taxi_out_min AS metric_value
    FROM flight_operations WHERE taxi_out_min > 180
    UNION ALL
    SELECT flight_id, carrier_code, flight_num, 'TARMAC_ARRIVAL_EXCEEDED' AS violation_type, taxi_in_min AS metric_value
    FROM flight_operations WHERE taxi_in_min > 180
);
COMMIT;

PROMPT Testing Stored Procedure 1: Carrier Audits (DL and WN)...
EXEC sp_carrier_performance_audit('DL');
EXEC sp_carrier_performance_audit('WN');

PROMPT Testing Stored Procedure 2: Corridor Congestion (JFK -> LAX)...
EXEC sp_route_congestion_analyzer('JFK', 'LAX');

SPOOL OFF;
PROMPT Triggers and Stored Procedures successfully compiled and verified!