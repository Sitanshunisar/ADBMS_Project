SET ECHO OFF;
SET FEEDBACK ON;

PROMPT ================================================================
PROMPT 1. Storage & Directory Object Setup
PROMPT ================================================================

BEGIN
    EXECUTE IMMEDIATE 'CREATE TABLESPACE flight_tbs
                       DATAFILE ''C:\database_project\flight_tbs01.dbf''
                       SIZE 500M AUTOEXTEND ON NEXT 100M MAXSIZE 4G
                       EXTENT MANAGEMENT LOCAL AUTOALLOCATE
                       SEGMENT SPACE MANAGEMENT AUTO';
    DBMS_OUTPUT.PUT_LINE('Tablespace FLIGHT_TBS created.');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -1543 THEN
            DBMS_OUTPUT.PUT_LINE('Tablespace FLIGHT_TBS already exists. Preserving data.');
        ELSE
            RAISE;
        END IF;
END;
/


BEGIN
    EXECUTE IMMEDIATE 'CREATE USER flightdb IDENTIFIED BY "FlightDb#2026"
                       DEFAULT TABLESPACE flight_tbs
                       TEMPORARY TABLESPACE temp
                       QUOTA UNLIMITED ON flight_tbs';
    DBMS_OUTPUT.PUT_LINE('User FLIGHTDB created.');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -1920 THEN
            DBMS_OUTPUT.PUT_LINE('User FLIGHTDB already exists. Password/quota preserved.');
        ELSE
            RAISE;
        END IF;
END;
/

GRANT CONNECT, RESOURCE TO flightdb;
GRANT CREATE TABLE, CREATE VIEW, CREATE SEQUENCE, CREATE PROCEDURE, CREATE TRIGGER TO flightdb;


CREATE OR REPLACE DIRECTORY bts_data_dir AS 'C:\database_project\data';
GRANT READ, WRITE ON DIRECTORY bts_data_dir TO flightdb;


PROMPT ================================================================
PROMPT 2. Least-Privilege Role & Analyst Provisioning (RBAC)
PROMPT ================================================================


BEGIN
    EXECUTE IMMEDIATE 'CREATE ROLE flight_analyst_role';
    DBMS_OUTPUT.PUT_LINE('Role FLIGHT_ANALYST_ROLE created.');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -1921 THEN
            DBMS_OUTPUT.PUT_LINE('Role FLIGHT_ANALYST_ROLE already exists.');
        ELSE
            RAISE;
        END IF;
END;
/


BEGIN
    EXECUTE IMMEDIATE 'CREATE USER flight_analyst IDENTIFIED BY "Analyst#2026"
                       DEFAULT TABLESPACE flight_tbs
                       TEMPORARY TABLESPACE temp
                       QUOTA 0 ON flight_tbs';
    DBMS_OUTPUT.PUT_LINE('User FLIGHT_ANALYST created.');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -1920 THEN
            DBMS_OUTPUT.PUT_LINE('User FLIGHT_ANALYST already exists.');
        ELSE
            RAISE;
        END IF;
END;
/

GRANT CREATE SESSION TO flight_analyst;
GRANT flight_analyst_role TO flight_analyst;
ALTER USER flight_analyst DEFAULT ROLE flight_analyst_role;


PROMPT ================================================================
PROMPT 3. Schema Grants to Role (Prefixing flightdb)
PROMPT ================================================================

GRANT SELECT ON flightdb.airports               TO flight_analyst_role;
GRANT SELECT ON flightdb.airlines               TO flight_analyst_role;
GRANT SELECT ON flightdb.aircraft_models        TO flight_analyst_role;
GRANT SELECT ON flightdb.aircraft_fleet         TO flight_analyst_role;
GRANT SELECT ON flightdb.flight_routes          TO flight_analyst_role;
GRANT SELECT ON flightdb.flight_operations      TO flight_analyst_role;
GRANT SELECT ON flightdb.delay_attributions     TO flight_analyst_role;
GRANT SELECT ON flightdb.flight_diversions      TO flight_analyst_role;
GRANT SELECT ON flightdb.regulatory_violations  TO flight_analyst_role;


PROMPT ================================================================
PROMPT 4. Public Synonyms for Clean Analyst Queries
PROMPT ================================================================

CREATE OR REPLACE PUBLIC SYNONYM airports              FOR flightdb.airports;
CREATE OR REPLACE PUBLIC SYNONYM airlines              FOR flightdb.airlines;
CREATE OR REPLACE PUBLIC SYNONYM aircraft_models       FOR flightdb.aircraft_models;
CREATE OR REPLACE PUBLIC SYNONYM aircraft_fleet        FOR flightdb.aircraft_fleet;
CREATE OR REPLACE PUBLIC SYNONYM flight_routes         FOR flightdb.flight_routes;
CREATE OR REPLACE PUBLIC SYNONYM flight_operations     FOR flightdb.flight_operations;
CREATE OR REPLACE PUBLIC SYNONYM delay_attributions    FOR flightdb.delay_attributions;
CREATE OR REPLACE PUBLIC SYNONYM flight_diversions     FOR flightdb.flight_diversions;
CREATE OR REPLACE PUBLIC SYNONYM regulatory_violations FOR flightdb.regulatory_violations;

PROMPT Initialization & RBAC Security Configuration Complete!