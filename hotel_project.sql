DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;
SET search_path TO public;

-- 1. DOMAIN / SUPERTYPE TABLES
CREATE TABLE HOTEL (
    HotelID       INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    HotelName     VARCHAR(100)  NOT NULL,
    Street        VARCHAR(120)  NOT NULL,      
    City          VARCHAR(60)   NOT NULL,
    Country       VARCHAR(60)   NOT NULL,
    PostalCode    VARCHAR(15),
    Phone         VARCHAR(25)   NOT NULL,
    CONSTRAINT uq_hotel_name UNIQUE (HotelName)
);

CREATE TABLE SPACE (
    SpaceID       INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    HotelID       INTEGER      NOT NULL REFERENCES HOTEL(HotelID) ON DELETE CASCADE,
    SpaceNumber   VARCHAR(10)  NOT NULL,
    Floor         INTEGER      NOT NULL CHECK (Floor >= 0),
    Status        VARCHAR(15)  NOT NULL DEFAULT 'AVAILABLE'
                    CHECK (Status IN ('AVAILABLE','OCCUPIED','MAINTENANCE','OUT_OF_SERVICE')),
    Capacity      INTEGER      NOT NULL CHECK (Capacity > 0),
    SpaceType     VARCHAR(15)  NOT NULL CHECK (SpaceType IN ('ACCOMMODATION','CONFERENCE')),
    CONSTRAINT uq_space_number_per_hotel UNIQUE (HotelID, SpaceNumber)
);

CREATE TABLE ACCOMMODATION_ROOM (
    SpaceID          INTEGER PRIMARY KEY REFERENCES SPACE(SpaceID) ON DELETE CASCADE,
    RoomCategory     VARCHAR(15) NOT NULL CHECK (RoomCategory IN ('STANDARD','LUXURY')),
    BedCount         INTEGER     NOT NULL CHECK (BedCount BETWEEN 1 AND 6),
    BaseNightlyRate  NUMERIC(10,2) NOT NULL CHECK (BaseNightlyRate >= 0)
);

CREATE TABLE CONFERENCE_ROOM (
    SpaceID       INTEGER PRIMARY KEY REFERENCES SPACE(SpaceID) ON DELETE CASCADE,
    HourlyRate    NUMERIC(10,2) NOT NULL CHECK (HourlyRate >= 0),
    SetupStyle    VARCHAR(20)   NOT NULL DEFAULT 'THEATER'
                    CHECK (SetupStyle IN ('THEATER','BOARDROOM','BANQUET','CLASSROOM'))
);

CREATE TABLE CUSTOMER (
    CustomerID       INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    CustomerName     VARCHAR(120) NOT NULL,
    Email            VARCHAR(120) NOT NULL UNIQUE,
    RegistrationDate DATE NOT NULL DEFAULT CURRENT_DATE,
    CustomerType     VARCHAR(10)  NOT NULL CHECK (CustomerType IN ('INDIVIDUAL','CORPORATE'))
);

CREATE TABLE CUSTOMER_PHONE (
    CustomerID   INTEGER NOT NULL REFERENCES CUSTOMER(CustomerID) ON DELETE CASCADE,
    PhoneNumber  VARCHAR(25) NOT NULL,
    PRIMARY KEY (CustomerID, PhoneNumber)
);

CREATE TABLE INDIVIDUAL_GUEST (
    CustomerID      INTEGER PRIMARY KEY REFERENCES CUSTOMER(CustomerID) ON DELETE CASCADE,
    LoyaltyPoints   INTEGER NOT NULL DEFAULT 0 CHECK (LoyaltyPoints >= 0),
    DateOfBirth     DATE,
    Nationality     VARCHAR(60)
);

CREATE TABLE CORPORATE_CUSTOMER (
    CustomerID          INTEGER PRIMARY KEY REFERENCES CUSTOMER(CustomerID) ON DELETE CASCADE,
    CompanyName         VARCHAR(120) NOT NULL,
    TaxID               VARCHAR(30)  NOT NULL UNIQUE,
    BillingAddress      VARCHAR(200) NOT NULL,
    ContactPersonName   VARCHAR(120) NOT NULL
);

CREATE TABLE EMPLOYEE (
    EmployeeID    INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    HotelID       INTEGER NOT NULL REFERENCES HOTEL(HotelID) ON DELETE RESTRICT,
    SupervisorID  INTEGER REFERENCES EMPLOYEE(EmployeeID) ON DELETE SET NULL,  -- recursive FK
    EmployeeName  VARCHAR(120) NOT NULL,
    HireDate      DATE NOT NULL,
    Salary        NUMERIC(10,2) NOT NULL CHECK (Salary > 0),
    Phone         VARCHAR(25) NOT NULL,
    EmployeeType  VARCHAR(15) NOT NULL
                    CHECK (EmployeeType IN ('RECEPTIONIST','HOUSEKEEPER','MANAGER','TECHNICIAN')),
    CHECK (SupervisorID IS NULL OR SupervisorID <> EmployeeID)
);

CREATE TABLE RECEPTIONIST (
    EmployeeID  INTEGER PRIMARY KEY REFERENCES EMPLOYEE(EmployeeID) ON DELETE CASCADE,
    ShiftType   VARCHAR(10) NOT NULL CHECK (ShiftType IN ('MORNING','EVENING','NIGHT'))
);

CREATE TABLE HOUSEKEEPER (
    EmployeeID     INTEGER PRIMARY KEY REFERENCES EMPLOYEE(EmployeeID) ON DELETE CASCADE,
    ShiftType      VARCHAR(10) NOT NULL CHECK (ShiftType IN ('MORNING','EVENING','NIGHT')),
    ZoneAssigned   VARCHAR(30) NOT NULL
);

CREATE TABLE MANAGER (
    EmployeeID       INTEGER PRIMARY KEY REFERENCES EMPLOYEE(EmployeeID) ON DELETE CASCADE,
    DepartmentName   VARCHAR(60) NOT NULL
);

CREATE TABLE TECHNICIAN (
    EmployeeID      INTEGER PRIMARY KEY REFERENCES EMPLOYEE(EmployeeID) ON DELETE CASCADE,
    Specialization  VARCHAR(60) NOT NULL
);

CREATE TABLE RESERVATION (
    ReservationID  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    CustomerID     INTEGER NOT NULL REFERENCES CUSTOMER(CustomerID) ON DELETE RESTRICT,
    CheckInDate    DATE NOT NULL,
    CheckOutDate   DATE NOT NULL,
    BookingDate    DATE NOT NULL DEFAULT CURRENT_DATE,
    Status         VARCHAR(12) NOT NULL DEFAULT 'CONFIRMED'
                     CHECK (Status IN ('CONFIRMED','CANCELLED','COMPLETED')),
    TotalCost      NUMERIC(12,2) NOT NULL DEFAULT 0,   -- derived attribute, kept up to date by trigger
    CHECK (CheckOutDate > CheckInDate)
);

CREATE TABLE RESERVATION_ROOM (
    ReservationID      INTEGER NOT NULL REFERENCES RESERVATION(ReservationID) ON DELETE CASCADE,
    SpaceID            INTEGER NOT NULL REFERENCES ACCOMMODATION_ROOM(SpaceID) ON DELETE RESTRICT,
    AgreedNightlyRate  NUMERIC(10,2) NOT NULL CHECK (AgreedNightlyRate >= 0),
    PRIMARY KEY (ReservationID, SpaceID)
);

CREATE TABLE SERVICE (
    ServiceID     INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ServiceName   VARCHAR(60) NOT NULL UNIQUE,
    Category      VARCHAR(30) NOT NULL,
    UnitPrice     NUMERIC(10,2) NOT NULL CHECK (UnitPrice >= 0)
);

CREATE TABLE SERVICE_USAGE (
    ServiceUsageID   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ReservationID    INTEGER NOT NULL REFERENCES RESERVATION(ReservationID) ON DELETE CASCADE,
    ServiceID        INTEGER NOT NULL REFERENCES SERVICE(ServiceID) ON DELETE RESTRICT,
    EmployeeID       INTEGER NOT NULL REFERENCES EMPLOYEE(EmployeeID) ON DELETE RESTRICT,
    Quantity         INTEGER NOT NULL DEFAULT 1 CHECK (Quantity > 0),
    UsageTimestamp   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE CONTRACT (
    ContractID           INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    CorporateCustomerID  INTEGER NOT NULL REFERENCES CORPORATE_CUSTOMER(CustomerID) ON DELETE CASCADE,
    ManagerID            INTEGER NOT NULL REFERENCES MANAGER(EmployeeID) ON DELETE RESTRICT,
    StartDate            DATE NOT NULL,
    EndDate              DATE,
    Terms                VARCHAR(300) NOT NULL,
    CHECK (EndDate IS NULL OR EndDate > StartDate)
);

CREATE TABLE CONFERENCE_BOOKING (
    BookingID            INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    CorporateCustomerID  INTEGER NOT NULL REFERENCES CORPORATE_CUSTOMER(CustomerID) ON DELETE RESTRICT,
    SpaceID              INTEGER NOT NULL REFERENCES CONFERENCE_ROOM(SpaceID) ON DELETE RESTRICT,
    ContractID           INTEGER REFERENCES CONTRACT(ContractID) ON DELETE SET NULL,
    EventDate            DATE NOT NULL,
    StartTime            TIME NOT NULL,
    EndTime              TIME NOT NULL,
    AttendeesCount       INTEGER NOT NULL CHECK (AttendeesCount > 0),
    Status               VARCHAR(12) NOT NULL DEFAULT 'CONFIRMED'
                          CHECK (Status IN ('CONFIRMED','CANCELLED','COMPLETED')),
    CHECK (EndTime > StartTime)
);

CREATE TABLE MAINTENANCE_TICKET (
    SpaceID        INTEGER NOT NULL REFERENCES SPACE(SpaceID) ON DELETE CASCADE,
    TicketNo       INTEGER NOT NULL,
    TechnicianID   INTEGER NOT NULL REFERENCES TECHNICIAN(EmployeeID) ON DELETE RESTRICT,
    ReportedDate   DATE NOT NULL DEFAULT CURRENT_DATE,
    Description    VARCHAR(300) NOT NULL,
    Status         VARCHAR(12) NOT NULL DEFAULT 'OPEN'
                    CHECK (Status IN ('OPEN','IN_PROGRESS','COMPLETED')),
    ResolvedDate   DATE,
    PRIMARY KEY (SpaceID, TicketNo),
    CHECK (ResolvedDate IS NULL OR ResolvedDate >= ReportedDate)
);

-- Helpful indexes for FK-heavy join columns
CREATE INDEX idx_space_hotel        ON SPACE(HotelID);
CREATE INDEX idx_employee_hotel     ON EMPLOYEE(HotelID);
CREATE INDEX idx_reservation_cust   ON RESERVATION(CustomerID);
CREATE INDEX idx_resroom_space      ON RESERVATION_ROOM(SpaceID);
CREATE INDEX idx_svcusage_res       ON SERVICE_USAGE(ReservationID);
CREATE INDEX idx_confbooking_space  ON CONFERENCE_BOOKING(SpaceID);

-- 3. TEST DATA

INSERT INTO HOTEL (HotelName, Street, City, Country, PostalCode, Phone) VALUES
('Aurora Grand Ankara',    'Ataturk Bulvari No:12', 'Ankara',   'Turkey', '06420', '+90-312-555-0101'),
('Aurora Bosphorus Istanbul','Sahil Yolu No:45',    'Istanbul', 'Turkey', '34349', '+90-212-555-0202'),
('Aurora Riviera Antalya', 'Konyaalti Cad. No:7',   'Antalya',  'Turkey', '07070', '+90-242-555-0303');

INSERT INTO SPACE (HotelID, SpaceNumber, Floor, Capacity, SpaceType) VALUES
(1,'101',1,2,'ACCOMMODATION'), (1,'102',1,2,'ACCOMMODATION'),
(1,'201',2,4,'ACCOMMODATION'), (1,'301',3,2,'ACCOMMODATION'),
(1,'C01',0,80,'CONFERENCE');

INSERT INTO SPACE (HotelID, SpaceNumber, Floor, Capacity, SpaceType) VALUES
(2,'101',1,2,'ACCOMMODATION'), (2,'102',1,3,'ACCOMMODATION'),
(2,'202',2,2,'ACCOMMODATION'), (2,'302',3,4,'ACCOMMODATION'),
(2,'C01',0,120,'CONFERENCE');

INSERT INTO SPACE (HotelID, SpaceNumber, Floor, Capacity, SpaceType) VALUES
(3,'101',1,2,'ACCOMMODATION'), (3,'201',2,2,'ACCOMMODATION'),
(3,'C01',0,60,'CONFERENCE');

INSERT INTO ACCOMMODATION_ROOM (SpaceID, RoomCategory, BedCount, BaseNightlyRate) VALUES
(1,'STANDARD',1, 60.00), (2,'STANDARD',2, 75.00), (3,'LUXURY',2, 140.00), (4,'LUXURY',1, 130.00),
(6,'STANDARD',1, 65.00), (7,'STANDARD',2, 80.00), (8,'LUXURY',2, 150.00), (9,'LUXURY',3, 190.00),
(11,'STANDARD',1, 55.00), (12,'LUXURY',2, 135.00);

INSERT INTO CONFERENCE_ROOM (SpaceID, HourlyRate, SetupStyle) VALUES
(5,  150.00, 'THEATER'),
(10, 220.00, 'BANQUET'),
(13, 120.00, 'BOARDROOM');

INSERT INTO CUSTOMER (CustomerName, Email, RegistrationDate, CustomerType) VALUES
('Elif Yildiz',    'elif.yildiz@example.com',    '2024-03-11', 'INDIVIDUAL'),
('Deniz Aydin',    'deniz.aydin@example.com',    '2024-05-02', 'INDIVIDUAL'),
('Zeynep Celik',   'zeynep.celik@example.com',   '2025-01-19', 'INDIVIDUAL'),
('Emre Sahin',     'emre.sahin@example.com',     '2023-11-27', 'INDIVIDUAL'),
('Burak Ozdemir',  'burak.ozdemir@example.com',  '2025-06-08', 'INDIVIDUAL'),
('Selin Aksoy',    'selin.aksoy@example.com',    '2024-09-14', 'INDIVIDUAL'),
('Kerem Polat',    'kerem.polat@example.com',    '2025-02-22', 'INDIVIDUAL'),
('Nihan Aktas',    'nihan.aktas@example.com',    '2023-08-30', 'INDIVIDUAL'),
('TechNova Yazilim A.S.',       'contact@technova.example.com',   '2023-04-01', 'CORPORATE'),
('Bilkent Danismanlik Ltd.',    'info@bilkentdanismanlik.example.com','2023-07-15', 'CORPORATE'),
('Anadolu Insaat Holding',      'office@anadoluinsaat.example.com','2024-01-10', 'CORPORATE'),
('Mavi Turizm Organizasyon',    'info@maviturizm.example.com',    '2024-02-20', 'CORPORATE'),
('GlobalTrade Lojistik A.S.',   'contact@globaltrade.example.com','2024-06-05', 'CORPORATE');

INSERT INTO CUSTOMER_PHONE (CustomerID, PhoneNumber) VALUES
(1,'+90-532-111-2201'), (1,'+90-312-444-9911'),
(2,'+90-533-222-3302'),
(3,'+90-535-333-4403'),
(4,'+90-536-444-5504'), (4,'+90-536-444-5505'),
(9,'+90-312-999-0001'),
(10,'+90-312-999-0002'),
(11,'+90-212-999-0003'),
(12,'+90-242-999-0004'),
(13,'+90-212-999-0005');

INSERT INTO INDIVIDUAL_GUEST (CustomerID, LoyaltyPoints, DateOfBirth, Nationality) VALUES
(1, 850, '1990-04-12','Turkish'),
(2, 120, '1985-09-23','Turkish'),
(3,  30, '1998-12-01','Turkish'),
(4,1200, '1979-02-17','Turkish'),
(5,   0, '2000-06-30','Turkish'),
(6, 460, '1993-11-05','Turkish'),
(7,  75, '1996-03-08','German'),
(8, 990, '1988-07-19','Turkish');

INSERT INTO CORPORATE_CUSTOMER (CustomerID, CompanyName, TaxID, BillingAddress, ContactPersonName) VALUES
(9,  'TechNova Yazilim A.S.',    'TX-100234', 'Cyberpark, Ankara, Turkey',       'Onur Kaplan'),
(10, 'Bilkent Danismanlik Ltd.', 'TX-100987', 'Bilkent, Ankara, Turkey',        'Aylin Er'),
(11, 'Anadolu Insaat Holding',   'TX-102233', 'Kizilay, Ankara, Turkey',        'Serkan Yavuz'),
(12, 'Mavi Turizm Organizasyon', 'TX-103344', 'Lara, Antalya, Turkey',          'Gizem Toprak'),
(13, 'GlobalTrade Lojistik A.S.','TX-104455', 'Levent, Istanbul, Turkey',       'Mert Sonmez');

INSERT INTO EMPLOYEE (HotelID, SupervisorID, EmployeeName, HireDate, Salary, Phone, EmployeeType) VALUES
(1, NULL, 'Ayse Kaya',    '2019-03-01', 62000.00, '+90-312-700-0001', 'MANAGER'),
(1, 1,    'Cem Aktug',    '2021-06-15', 32000.00, '+90-312-700-0002', 'RECEPTIONIST'),
(1, 1,    'Fatma Sanli',  '2020-02-10', 28000.00, '+90-312-700-0003', 'HOUSEKEEPER'),
(1, 1,    'Baris Kurt',   '2022-01-20', 34000.00, '+90-312-700-0004', 'TECHNICIAN'),
(2, NULL, 'Mehmet Demir', '2018-05-11', 64000.00, '+90-212-700-0005', 'MANAGER'),
(2, 5,    'Gul Ates',     '2021-09-01', 32500.00, '+90-212-700-0006', 'RECEPTIONIST'),
(2, 5,    'Onder Yilmaz', '2020-11-23', 28500.00, '+90-212-700-0007', 'HOUSEKEEPER'),
(2, 5,    'Sibel Koc',    '2022-04-18', 34500.00, '+90-212-700-0008', 'TECHNICIAN'),
(3, 5,    'Tolga Ceylan', '2023-02-14', 31000.00, '+90-242-700-0009', 'RECEPTIONIST'),
(3, 5,    'Derya Bulut',  '2022-08-09', 27500.00, '+90-242-700-0010', 'HOUSEKEEPER');

INSERT INTO MANAGER      (EmployeeID, DepartmentName) VALUES (1,'Front Office & Operations'), (5,'Front Office & Operations');
INSERT INTO RECEPTIONIST (EmployeeID, ShiftType) VALUES (2,'MORNING'), (6,'MORNING'), (9,'EVENING');
INSERT INTO HOUSEKEEPER  (EmployeeID, ShiftType, ZoneAssigned) VALUES (3,'MORNING','Floors 1-3'), (7,'MORNING','Floors 1-3'), (10,'EVENING','Floors 1-2');
INSERT INTO TECHNICIAN   (EmployeeID, Specialization) VALUES (4,'Electrical & HVAC'), (8,'Plumbing & Electrical');

INSERT INTO RESERVATION (CustomerID, CheckInDate, CheckOutDate, BookingDate, Status) VALUES
(1, '2026-07-01', '2026-07-04', '2026-06-10', 'COMPLETED'),   -- 1
(2, '2026-07-05', '2026-07-07', '2026-06-15', 'CONFIRMED'),   -- 2
(3, '2026-07-10', '2026-07-12', '2026-06-20', 'CONFIRMED'),   -- 3
(4, '2026-06-01', '2026-06-05', '2026-05-10', 'COMPLETED'),   -- 4  multi-room
(5, '2026-06-10', '2026-06-12', '2026-05-20', 'CANCELLED'),   -- 5
(6, '2026-07-15', '2026-07-18', '2026-06-25', 'CONFIRMED'),   -- 6
(7, '2026-07-20', '2026-07-22', '2026-06-28', 'CONFIRMED'),   -- 7
(8, '2026-07-25', '2026-07-28', '2026-07-01', 'CONFIRMED'),   -- 8  multi-room
(1, '2026-08-01', '2026-08-03', '2026-07-05', 'CONFIRMED'),   -- 9
(2, '2026-08-05', '2026-08-06', '2026-07-10', 'CONFIRMED'),   -- 10
(3, '2026-08-10', '2026-08-14', '2026-07-12', 'CONFIRMED'),   -- 11 multi-room
(4, '2026-05-01', '2026-05-03', '2026-04-10', 'COMPLETED'),   -- 12
(5, '2026-05-15', '2026-05-17', '2026-04-20', 'COMPLETED'),   -- 13
(6, '2026-09-01', '2026-09-03', '2026-08-05', 'CONFIRMED'),   -- 14
(7, '2026-09-10', '2026-09-12', '2026-08-08', 'CONFIRMED');   -- 15

INSERT INTO RESERVATION_ROOM (ReservationID, SpaceID, AgreedNightlyRate) VALUES
(1, 1, 60.00),
(2, 2, 75.00),
(3, 3, 140.00),
(4, 1, 60.00), (4, 2, 75.00),                 -- multi-room #1
(5, 4, 130.00),
(6, 6, 65.00),
(7, 7, 80.00),
(8, 6, 65.00), (8, 7, 80.00),                 -- multi-room #2
(9, 8, 150.00),
(10, 9, 190.00),
(11, 11, 55.00), (11, 12, 135.00),            -- multi-room #3
(12, 3, 140.00),
(13, 4, 130.00),
(14, 1, 60.00),
(15, 2, 75.00);

INSERT INTO SERVICE (ServiceName, Category, UnitPrice) VALUES
('In-Room Dining',   'FOOD_BEVERAGE', 18.00),
('Spa Session',      'WELLNESS',      55.00),
('Airport Transit',  'TRANSPORT',     40.00),
('Laundry Service',  'HOUSEKEEPING',  12.00);

INSERT INTO SERVICE_USAGE (ReservationID, ServiceID, EmployeeID, Quantity, UsageTimestamp) VALUES
(1, 1, 2, 2, '2026-07-01 19:30:00'),
(1, 4, 3, 1, '2026-07-02 10:00:00'),
(2, 2, 6, 1, '2026-07-06 15:00:00'),
(3, 3, 9, 1, '2026-07-11 08:00:00'),
(4, 1, 2, 3, '2026-06-02 20:00:00'),
(4, 2, 6, 2, '2026-06-03 16:00:00'),
(6, 1, 6, 1, '2026-07-16 19:00:00'),
(7, 3, 9, 1, '2026-07-21 09:00:00'),
(8, 4, 7, 2, '2026-07-26 11:00:00'),
(9, 1, 2, 1, '2026-08-01 20:30:00'),
(10, 2, 6, 1, '2026-08-05 17:00:00'),
(11, 1, 9, 2, '2026-08-11 19:00:00'),
(11, 3, 9, 1, '2026-08-12 07:30:00'),
(9, 2, 2, 1, '2026-08-01 21:00:00'),
(9, 3, 2, 1, '2026-08-02 08:00:00');

INSERT INTO CONTRACT (CorporateCustomerID, ManagerID, StartDate, EndDate, Terms) VALUES
(9,  1, '2025-01-01', '2027-01-01', 'Annual conference-space partnership, 10% corporate discount.'),
(10, 5, '2025-03-01', '2026-12-31', 'Quarterly boardroom retainer agreement.'),
(11, 1, '2024-11-01', NULL,          'Open-ended events partnership, invoiced monthly.'),
(12, 5, '2025-06-01', '2026-06-01', 'Single-season banquet and events agreement.'),
(13, 1, '2025-02-15', '2027-02-15', 'Logistics division annual training-event contract.'),
(13, 1, '2026-07-01', NULL,          'New pilot contract for quarterly team offsites - pending first scheduled event.');

INSERT INTO CONFERENCE_BOOKING (CorporateCustomerID, SpaceID, ContractID, EventDate, StartTime, EndTime, AttendeesCount, Status) VALUES
(9,  5,  1, '2026-07-14', '09:00', '17:00', 60, 'CONFIRMED'),
(10, 13, 2, '2026-07-20', '10:00', '13:00', 15, 'CONFIRMED'),
(11, 5,  3, '2026-08-02', '09:00', '18:00', 75, 'CONFIRMED'),
(12, 10, 4, '2026-08-15', '14:00', '20:00', 100,'CONFIRMED'),
(13, 10, 5, '2026-09-05', '09:00', '12:00', 40, 'COMPLETED'),
(9,  10, 1, '2026-08-20', '09:00', '12:00', 30, 'CONFIRMED'),
(9,  13, 1, '2026-09-10', '13:00', '16:00', 20, 'CONFIRMED');

INSERT INTO MAINTENANCE_TICKET (SpaceID, TicketNo, TechnicianID, ReportedDate, Description, Status, ResolvedDate) VALUES
(3,  1, 4, '2026-06-20', 'Air conditioning unit not cooling properly.', 'COMPLETED', '2026-06-21'),
(9,  1, 8, '2026-07-02', 'Leaking bathroom faucet.',                    'COMPLETED', '2026-07-03'),
(12, 1, 8, '2026-07-18', 'Room key card reader malfunctioning.',        'OPEN',       NULL);


-- 4. TRIGGERS
-- 4.1 MANDATORY: Overlap Prevention Trigger
CREATE OR REPLACE FUNCTION fn_prevent_room_overlap() RETURNS TRIGGER AS $$
DECLARE
    v_checkin  DATE;
    v_checkout DATE;
    v_conflict INTEGER;
BEGIN
    SELECT CheckInDate, CheckOutDate INTO v_checkin, v_checkout
    FROM RESERVATION WHERE ReservationID = NEW.ReservationID;

    SELECT COUNT(*) INTO v_conflict
    FROM RESERVATION_ROOM rr
    JOIN RESERVATION r ON r.ReservationID = rr.ReservationID
    WHERE rr.SpaceID = NEW.SpaceID
      AND r.Status <> 'CANCELLED'
      AND r.ReservationID <> NEW.ReservationID
      AND v_checkin  < r.CheckOutDate
      AND r.CheckInDate < v_checkout;

    IF v_conflict > 0 THEN
        RAISE EXCEPTION 'Overlap detected: SpaceID % is already reserved for an overlapping date range (%,%).',
            NEW.SpaceID, v_checkin, v_checkout;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_room_overlap
BEFORE INSERT OR UPDATE ON RESERVATION_ROOM
FOR EACH ROW EXECUTE FUNCTION fn_prevent_room_overlap();

--4.2 Additional trigger to maintain the derived RESERVATION.
CREATE OR REPLACE FUNCTION fn_recalculate_reservation_total() RETURNS TRIGGER AS $$
DECLARE
    v_reservation_id INTEGER;
    v_room_cost      NUMERIC(12,2);
    v_service_cost   NUMERIC(12,2);
BEGIN
    v_reservation_id := COALESCE(NEW.ReservationID, OLD.ReservationID);

    SELECT COALESCE(SUM(rr.AgreedNightlyRate *
                         (r.CheckOutDate - r.CheckInDate)), 0)
      INTO v_room_cost
      FROM RESERVATION_ROOM rr JOIN RESERVATION r ON r.ReservationID = rr.ReservationID
      WHERE rr.ReservationID = v_reservation_id;

    SELECT COALESCE(SUM(su.Quantity * s.UnitPrice), 0)
      INTO v_service_cost
      FROM SERVICE_USAGE su JOIN SERVICE s ON s.ServiceID = su.ServiceID
      WHERE su.ReservationID = v_reservation_id;

    UPDATE RESERVATION
       SET TotalCost = v_room_cost + v_service_cost
     WHERE ReservationID = v_reservation_id;

    RETURN NULL; 
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_recalc_total_after_room
AFTER INSERT OR UPDATE OR DELETE ON RESERVATION_ROOM
FOR EACH ROW EXECUTE FUNCTION fn_recalculate_reservation_total();

CREATE TRIGGER trg_recalc_total_after_service
AFTER INSERT OR UPDATE OR DELETE ON SERVICE_USAGE
FOR EACH ROW EXECUTE FUNCTION fn_recalculate_reservation_total();

-- 4.3 Additional trigger to close the overlap-check gap on RESERVATION date edits

CREATE OR REPLACE FUNCTION fn_prevent_overlap_on_reservation_dates() RETURNS TRIGGER AS $$
DECLARE
    v_conflict INTEGER;
BEGIN
    IF NEW.CheckInDate IS DISTINCT FROM OLD.CheckInDate
       OR NEW.CheckOutDate IS DISTINCT FROM OLD.CheckOutDate THEN

        SELECT COUNT(*) INTO v_conflict
        FROM RESERVATION_ROOM rr
        JOIN RESERVATION r ON r.ReservationID = rr.ReservationID
        WHERE rr.SpaceID IN (SELECT SpaceID FROM RESERVATION_ROOM WHERE ReservationID = NEW.ReservationID)
          AND rr.ReservationID <> NEW.ReservationID
          AND r.Status <> 'CANCELLED'
          AND NEW.CheckInDate  < r.CheckOutDate
          AND r.CheckInDate    < NEW.CheckOutDate;

        IF v_conflict > 0 THEN
            RAISE EXCEPTION 'Overlap detected: changing ReservationID % to (%,%) would conflict with another reservation of one of its already-booked rooms.',
                NEW.ReservationID, NEW.CheckInDate, NEW.CheckOutDate;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_overlap_on_reservation_dates
BEFORE UPDATE OF CheckInDate, CheckOutDate ON RESERVATION
FOR EACH ROW EXECUTE FUNCTION fn_prevent_overlap_on_reservation_dates();

UPDATE RESERVATION r SET TotalCost = TotalCost;  
UPDATE RESERVATION SET TotalCost = (
    SELECT COALESCE(SUM(rr.AgreedNightlyRate * (r2.CheckOutDate - r2.CheckInDate)), 0)
    FROM RESERVATION_ROOM rr JOIN RESERVATION r2 ON r2.ReservationID = rr.ReservationID
    WHERE rr.ReservationID = RESERVATION.ReservationID
) + (
    SELECT COALESCE(SUM(su.Quantity * s.UnitPrice), 0)
    FROM SERVICE_USAGE su JOIN SERVICE s ON s.ServiceID = su.ServiceID
    WHERE su.ReservationID = RESERVATION.ReservationID
);

-- 5. VIEWS  (protect baseline infrastructure text fields / serve analytics)

CREATE VIEW v_employee_directory AS
SELECT e.EmployeeID, e.EmployeeName, e.EmployeeType, h.HotelName,
       e.HireDate,
       sup.EmployeeName AS SupervisorName
FROM EMPLOYEE e
JOIN HOTEL h ON h.HotelID = e.HotelID
LEFT JOIN EMPLOYEE sup ON sup.EmployeeID = e.SupervisorID;

CREATE VIEW v_hotel_revenue_summary AS
SELECT h.HotelID, h.HotelName,
       COALESCE(SUM(rr.AgreedNightlyRate * (r.CheckOutDate - r.CheckInDate)), 0) AS RoomRevenue,
       COALESCE((SELECT SUM(su.Quantity * s.UnitPrice)
                   FROM SERVICE_USAGE su
                   JOIN SERVICE s ON s.ServiceID = su.ServiceID
                   JOIN RESERVATION r2 ON r2.ReservationID = su.ReservationID
                   JOIN RESERVATION_ROOM rr2 ON rr2.ReservationID = r2.ReservationID
                   JOIN SPACE sp2 ON sp2.SpaceID = rr2.SpaceID
                  WHERE sp2.HotelID = h.HotelID), 0) AS ServiceRevenue
FROM HOTEL h
LEFT JOIN SPACE sp ON sp.HotelID = h.HotelID
LEFT JOIN RESERVATION_ROOM rr ON rr.SpaceID = sp.SpaceID
LEFT JOIN RESERVATION r ON r.ReservationID = rr.ReservationID AND r.Status <> 'CANCELLED'
GROUP BY h.HotelID, h.HotelName;

CREATE VIEW v_room_availability AS
SELECT sp.SpaceID, h.HotelName, sp.SpaceNumber, sp.SpaceType, sp.Status,
       ar.RoomCategory, ar.BaseNightlyRate,
       cr.SetupStyle, cr.HourlyRate
FROM SPACE sp
JOIN HOTEL h ON h.HotelID = sp.HotelID
LEFT JOIN ACCOMMODATION_ROOM ar ON ar.SpaceID = sp.SpaceID
LEFT JOIN CONFERENCE_ROOM cr ON cr.SpaceID = sp.SpaceID;

-- 6. QUERIES  (8 basic/advanced SQL queries)

-- Q1. Basic selection and projection:
-- VIP individual guests (LoyaltyPoints > 500), with a computed VIP tier label.
SELECT c.CustomerName, ig.LoyaltyPoints,
       CASE WHEN ig.LoyaltyPoints >= 1000 THEN 'Platinum' ELSE 'Gold' END AS VipTier
FROM CUSTOMER c
JOIN INDIVIDUAL_GUEST ig ON ig.CustomerID = c.CustomerID
WHERE ig.LoyaltyPoints > 500
ORDER BY ig.LoyaltyPoints DESC;

-- Q2. Three-table join:
-- Show, for every reservation, the guest's name, the hotel name, and the room number booked.
SELECT c.CustomerName, h.HotelName, sp.SpaceNumber, r.CheckInDate, r.CheckOutDate
FROM RESERVATION r
JOIN CUSTOMER c ON c.CustomerID = r.CustomerID
JOIN RESERVATION_ROOM rr ON rr.ReservationID = r.ReservationID
JOIN SPACE sp ON sp.SpaceID = rr.SpaceID
JOIN HOTEL h ON h.HotelID = sp.HotelID
ORDER BY r.ReservationID;

-- Q3. Outer join (recursive self-join on EMPLOYEE):
-- Every manager, together with the size of their supervised team (0 included).
SELECT mgr.EmployeeName AS ManagerName, h.HotelName,
       COUNT(sub.EmployeeID) AS TeamSize
FROM EMPLOYEE mgr
JOIN MANAGER m ON m.EmployeeID = mgr.EmployeeID
JOIN HOTEL h ON h.HotelID = mgr.HotelID
LEFT JOIN EMPLOYEE sub ON sub.SupervisorID = mgr.EmployeeID
GROUP BY mgr.EmployeeName, h.HotelName
ORDER BY TeamSize DESC;

-- Q4. Aggregate function with GROUP BY:
-- Average attendee count and total revenue generated per conference SetupStyle.
SELECT cr.SetupStyle,
       ROUND(AVG(cb.AttendeesCount), 1) AS AvgAttendees,
       ROUND(SUM(cr.HourlyRate * EXTRACT(EPOCH FROM (cb.EndTime - cb.StartTime)) / 3600.0), 2) AS TotalRevenue
FROM CONFERENCE_BOOKING cb
JOIN CONFERENCE_ROOM cr ON cr.SpaceID = cb.SpaceID
WHERE cb.Status <> 'CANCELLED'
GROUP BY cr.SetupStyle
ORDER BY TotalRevenue DESC;

-- Q5. HAVING:
-- Guests with more than 1 (non-cancelled) reservation AND an average reservation
-- cost above 300 (threshold chosen from the populated test data: it separates
-- the two highest-spending repeat guests from the rest).
SELECT c.CustomerName, COUNT(*) AS ReservationCount, ROUND(AVG(r.TotalCost), 2) AS AvgCost
FROM CUSTOMER c
JOIN RESERVATION r ON r.CustomerID = c.CustomerID
WHERE r.Status <> 'CANCELLED'
GROUP BY c.CustomerName
HAVING COUNT(*) > 1 AND AVG(r.TotalCost) > 300
ORDER BY AvgCost DESC;

-- Q6. Nested query:
-- Corporate customers whose conference bookings drew more attendees than the
-- average AttendeesCount across all (non-cancelled) conference bookings.
SELECT DISTINCT cc.CompanyName, cb.BookingID, cb.AttendeesCount
FROM CONFERENCE_BOOKING cb
JOIN CORPORATE_CUSTOMER cc ON cc.CustomerID = cb.CorporateCustomerID
WHERE cb.Status <> 'CANCELLED'
  AND cb.AttendeesCount > (
        SELECT AVG(AttendeesCount) FROM CONFERENCE_BOOKING WHERE Status <> 'CANCELLED'
      )
ORDER BY cb.AttendeesCount DESC;

-- Q7. Correlated NOT EXISTS:
-- "Contract lifecycle risk": corporate customers who hold a CONTRACT under
-- which NOT A SINGLE conference booking has ever been made.
SELECT cc.CompanyName, ct.ContractID, ct.StartDate, ct.EndDate
FROM CONTRACT ct
JOIN CORPORATE_CUSTOMER cc ON cc.CustomerID = ct.CorporateCustomerID
WHERE NOT EXISTS (
    SELECT 1 FROM CONFERENCE_BOOKING cb
    WHERE cb.ContractID = ct.ContractID AND cb.Status <> 'CANCELLED'
)
ORDER BY ct.StartDate;

-- Q8. Set operation / division-style query:
-- Guests who have used EVERY service category offered by the hotel chain at
-- least once (relational division on SERVICE.Category rather than on hotels).
SELECT c.CustomerName
FROM CUSTOMER c
WHERE NOT EXISTS (
    SELECT s.Category
    FROM SERVICE s
    EXCEPT
    SELECT s2.Category
    FROM SERVICE_USAGE su
    JOIN SERVICE s2 ON s2.ServiceID = su.ServiceID
    JOIN RESERVATION r ON r.ReservationID = su.ReservationID
    WHERE r.CustomerID = c.CustomerID
);

-- TRIGGER TESTS (Commented out for clean execution)
-- To test the overlap prevention triggers, uncomment the blocks below
-- and execute them individually. Test 1 and 2 will throw expected 
-- exceptions, while Test 3 will succeed.

-- Test 1 - Mandatory trigger: A new reservation with overlapping dates must be rejected
/*BEGIN;

INSERT INTO RESERVATION (CustomerID, CheckInDate, CheckOutDate, Status)
VALUES (2, '2026-07-02', '2026-07-03', 'CONFIRMED');

INSERT INTO RESERVATION_ROOM (ReservationID, SpaceID, AgreedNightlyRate)
VALUES (currval(pg_get_serial_sequence('reservation','reservationid')), 1, 60.00);

ROLLBACK;
*/

-- Test 2 - Additional trigger: A date update on RESERVATION causing an overlap must be rejected
/*BEGIN;

UPDATE RESERVATION
SET CheckInDate = '2026-09-11', CheckOutDate = '2026-09-13'
WHERE ReservationID = 2;

ROLLBACK;
*/

-- Test 3 - Same trigger: A legitimate, non-overlapping date update must succeed

/*BEGIN;

UPDATE RESERVATION
SET CheckInDate = '2026-07-06', CheckOutDate = '2026-07-08'
WHERE ReservationID = 2;

SELECT reservationid, checkindate, checkoutdate
FROM RESERVATION
WHERE reservationid = 2;

ROLLBACK;
*/