-- 1. СОЗДАНИЕ ENUM-ТИПОВ
CREATE TYPE employee_position_enum AS ENUM ('manager', 'cashier', 'technician');
CREATE TYPE inventory_state_enum AS ENUM ('available', 'booked', 'rented', 'needs_repair', 'in_repair', 'in_transfer', 'written_off');
CREATE TYPE inventory_condition_enum AS ENUM ('good', 'worn', 'damaged');
CREATE TYPE rent_state_enum AS ENUM ('active', 'completed', 'overdue');
CREATE TYPE request_status_enum AS ENUM ('pending', 'in_progress', 'completed', 'cancelled');
CREATE TYPE transfer_status_enum AS ENUM ('created', 'in_transit', 'delivered', 'cancelled');
CREATE TYPE writeoff_reason_enum AS ENUM ('over_worn', 'broken_beyond_repair', 'lost', 'expired');

-- 2. БАЗОВЫЕ СПРАВОЧНИКИ (БЕЗ ВНЕШНИХ КЛЮЧЕЙ)
CREATE TABLE RentalSpot (ID BIGSERIAL PRIMARY KEY, Address VARCHAR(255) NOT NULL);
CREATE TABLE InventoryType (ID BIGSERIAL PRIMARY KEY, Name VARCHAR(50) NOT NULL, Durability INTERVAL);
CREATE TABLE Client (ID BIGSERIAL PRIMARY KEY, Name VARCHAR(150) NOT NULL, Email VARCHAR(150) NOT NULL UNIQUE, psswrd VARCHAR(255) NOT NULL);
CREATE TABLE RepairCenter (ID BIGSERIAL PRIMARY KEY, Address VARCHAR(255) NOT NULL);
CREATE TABLE Opponents (ID BIGSERIAL PRIMARY KEY, OrgName VARCHAR(150), Address VARCHAR(255));

-- 3. ОСНОВНЫЕ СУЩНОСТИ ПЕРВОГО УРОВНЯ
CREATE TABLE Employee (ID BIGSERIAL PRIMARY KEY, Name VARCHAR(150), Position employee_position_enum, RentalSpot BIGINT REFERENCES RentalSpot(ID) ON DELETE SET NULL);
CREATE TABLE Inventory (ID BIGSERIAL PRIMARY KEY, Type BIGINT NOT NULL REFERENCES InventoryType(ID) ON DELETE RESTRICT, Size REAL NOT NULL CHECK (Size > 0), State inventory_state_enum NOT NULL DEFAULT 'available', Condition inventory_condition_enum DEFAULT 'good', BookingPercent REAL NOT NULL CHECK (BookingPercent >= 0 AND BookingPercent <= 100));
CREATE TABLE OpponentPrices (ID BIGSERIAL PRIMARY KEY, InventoryType BIGINT REFERENCES InventoryType(ID) ON DELETE CASCADE, OpSpotID BIGINT REFERENCES Opponents(ID) ON DELETE CASCADE, Size REAL CHECK (Size > 0), Amount INT CHECK (Amount >= 0));
CREATE TABLE DemandForecast (InventoryType BIGINT REFERENCES InventoryType(ID) ON DELETE CASCADE, SpotID BIGINT REFERENCES RentalSpot(ID) ON DELETE CASCADE, Size REAL CHECK (Size > 0), Amount INT CHECK (Amount >= 0), PRIMARY KEY (InventoryType, SpotID));

-- 4. ОПЕРАЦИОННЫЕ ТАБЛИЦЫ И СВЯЗИ M:N
CREATE TABLE InStock (SpotID BIGINT REFERENCES RentalSpot(ID) ON DELETE RESTRICT, InventoryID BIGINT REFERENCES Inventory(ID) ON DELETE CASCADE, PRIMARY KEY (SpotID, InventoryID));
CREATE TABLE Pricing (InventoryID BIGINT REFERENCES Inventory(ID) ON DELETE CASCADE, SpotID BIGINT REFERENCES RentalSpot(ID) ON DELETE SET NULL, Price REAL CHECK (Price >= 0), PRIMARY KEY (InventoryID, SpotID));
CREATE TABLE Purchase (ID BIGSERIAL PRIMARY KEY, InventoryID BIGINT REFERENCES Inventory(ID) ON DELETE SET NULL, TypeID BIGINT NOT NULL REFERENCES InventoryType(ID) ON DELETE RESTRICT, Price REAL NOT NULL CHECK (Price >= 0), Source VARCHAR(255) NOT NULL, Date DATE NOT NULL DEFAULT CURRENT_DATE);
CREATE TABLE WriteOff (ID BIGSERIAL PRIMARY KEY, InventoryID BIGINT REFERENCES Inventory(ID) ON DELETE SET NULL, ExploitationDuration INTERVAL, Reason writeoff_reason_enum, Date DATE DEFAULT CURRENT_DATE);
CREATE TABLE Booking (ID BIGSERIAL PRIMARY KEY, ClientID BIGINT NOT NULL REFERENCES Client(ID) ON DELETE RESTRICT, InventoryID BIGINT REFERENCES Inventory(ID) ON DELETE SET NULL, BookingStart TIMESTAMP NOT NULL, BookingEnd TIMESTAMP NOT NULL, BookingPrice REAL NOT NULL CHECK (BookingPrice >= 0), CHECK (BookingEnd > BookingStart));
CREATE TABLE Rent (ID BIGSERIAL PRIMARY KEY, ClientID BIGINT NOT NULL REFERENCES Client(ID) ON DELETE RESTRICT, InventoryID BIGINT REFERENCES Inventory(ID) ON DELETE SET NULL, EmployeeID BIGINT REFERENCES Employee(ID) ON DELETE SET NULL, SpotID BIGINT NOT NULL REFERENCES RentalSpot(ID) ON DELETE RESTRICT, Duration INTERVAL NOT NULL, State rent_state_enum NOT NULL DEFAULT 'active', Date DATE NOT NULL DEFAULT CURRENT_DATE);
CREATE TABLE RepairRequest (ID BIGSERIAL PRIMARY KEY, RepairCenterID BIGINT REFERENCES RepairCenter(ID) ON DELETE SET NULL, InventoryID BIGINT NOT NULL REFERENCES Inventory(ID) ON DELETE CASCADE, Price REAL NOT NULL CHECK (Price >= 0), Status request_status_enum NOT NULL DEFAULT 'pending');
CREATE TABLE Transfer (ID BIGSERIAL PRIMARY KEY, SenderSpotID BIGINT NOT NULL REFERENCES RentalSpot(ID) ON DELETE RESTRICT, RecipientSpotID BIGINT NOT NULL REFERENCES RentalSpot(ID) ON DELETE RESTRICT, Price REAL NOT NULL CHECK (Price >= 0), Status transfer_status_enum NOT NULL DEFAULT 'created', CHECK (SenderSpotID <> RecipientSpotID));
CREATE TABLE Package (ID BIGSERIAL PRIMARY KEY, InventoryID BIGINT NOT NULL REFERENCES Inventory(ID) ON DELETE CASCADE, TransferID BIGINT NOT NULL REFERENCES Transfer(ID) ON DELETE CASCADE);
CREATE TABLE Notification (ID BIGSERIAL PRIMARY KEY, AddressedToEmployees BIGINT REFERENCES Employee(ID) ON DELETE SET NULL, Message TEXT NOT NULL);
CREATE TABLE AddressTo (ID BIGSERIAL PRIMARY KEY, EmployeeID BIGINT NOT NULL REFERENCES Employee(ID) ON DELETE CASCADE, NotificationID BIGINT NOT NULL REFERENCES Notification(ID) ON DELETE CASCADE);
