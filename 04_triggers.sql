SET DEFINE OFF;

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

-- One-time Batch Backfill for existing records in FLIGHT_OPERATIONS
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

PROMPT Compliance Triggers and Audit Ledger Deployed!