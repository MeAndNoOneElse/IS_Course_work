CREATE OR REPLACE FUNCTION trg_validate_booking_fn()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_state inventory_state_enum;
    v_condition inventory_condition_enum;
    v_conflict_exists BOOLEAN;
BEGIN
    IF NEW.InventoryID IS NOT NULL THEN
        SELECT State, Condition INTO v_state, v_condition FROM Inventory WHERE ID = NEW.InventoryID;
        IF v_condition = 'damaged' OR v_state IN ('needs_repair', 'in_repair', 'written_off') THEN
            RAISE EXCEPTION 'Невозможно забронировать неисправный или списанный инвентарь (ID: %)', NEW.InventoryID;
        END IF;
        SELECT EXISTS (SELECT 1 FROM Booking b WHERE b.InventoryID = NEW.InventoryID AND b.ID <> COALESCE(NEW.ID, -1) AND b.BookingStart < (NEW.BookingEnd + INTERVAL '20 minutes') AND (b.BookingEnd + INTERVAL '20 minutes') > NEW.BookingStart) INTO v_conflict_exists;
        IF v_conflict_exists THEN RAISE EXCEPTION 'Конфликт времени бронирования для инвентаря ID %', NEW.InventoryID; END IF;
        IF v_state = 'available' THEN UPDATE Inventory SET State = 'booked' WHERE ID = NEW.InventoryID; END IF;
    END IF;
    RETURN NEW;
END; $$;

CREATE TRIGGER trg_validate_booking BEFORE INSERT OR UPDATE ON Booking FOR EACH ROW EXECUTE FUNCTION trg_validate_booking_fn();

CREATE OR REPLACE FUNCTION trg_process_writeoff_fn()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.InventoryID IS NOT NULL THEN
        UPDATE Inventory SET State = 'written_off' WHERE ID = NEW.InventoryID;
        DELETE FROM InStock WHERE InventoryID = NEW.InventoryID;
        DELETE FROM Booking WHERE InventoryID = NEW.InventoryID AND BookingStart > CURRENT_TIMESTAMP;
    END IF;
    RETURN NEW;
END; $$;

CREATE TRIGGER trg_process_writeoff AFTER INSERT ON WriteOff FOR EACH ROW EXECUTE FUNCTION trg_process_writeoff_fn();

CREATE OR REPLACE FUNCTION trg_package_add_item_fn()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_sender_spot BIGINT;
    v_is_on_spot BOOLEAN;
BEGIN
    SELECT SenderSpotID INTO v_sender_spot FROM Transfer WHERE ID = NEW.TransferID;
    SELECT EXISTS (SELECT 1 FROM InStock WHERE SpotID = v_sender_spot AND InventoryID = NEW.InventoryID) INTO v_is_on_spot;
    IF NOT v_is_on_spot THEN RAISE EXCEPTION 'Инвентарь ID % отсутствует на точке отправителя (SpotID: %)', NEW.InventoryID, v_sender_spot; END IF;
    DELETE FROM InStock WHERE SpotID = v_sender_spot AND InventoryID = NEW.InventoryID;
    UPDATE Inventory SET State = 'in_transfer' WHERE ID = NEW.InventoryID;
    RETURN NEW;
END; $$;

CREATE TRIGGER trg_package_add_item AFTER INSERT ON Package FOR EACH ROW EXECUTE FUNCTION trg_package_add_item_fn();

CREATE OR REPLACE FUNCTION trg_transfer_status_change_fn()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.Status = 'delivered' AND OLD.Status <> 'delivered' THEN
        INSERT INTO InStock (SpotID, InventoryID) SELECT NEW.RecipientSpotID, p.InventoryID FROM Package p WHERE p.TransferID = NEW.ID ON CONFLICT (SpotID, InventoryID) DO NOTHING;
        UPDATE Inventory SET State = 'available' WHERE ID IN (SELECT InventoryID FROM Package WHERE TransferID = NEW.ID);
    END IF;
    RETURN NEW;
END; $$;

CREATE TRIGGER trg_transfer_status_change AFTER UPDATE OF Status ON Transfer FOR EACH ROW EXECUTE FUNCTION trg_transfer_status_change_fn();
