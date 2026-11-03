CREATE OR REPLACE PROCEDURE issue_inventory_for_rent(
    p_client_id BIGINT,
    p_inventory_id BIGINT,
    p_employee_id BIGINT,
    p_spot_id BIGINT,
    p_duration INTERVAL
)
LANGUAGE plpgsql
AS $$
DECLARE
v_state inventory_state_enum;
    v_condition inventory_condition_enum;
    v_in_stock BOOLEAN;
    v_client_booking_id BIGINT;
    v_other_booking_exists BOOLEAN;
BEGIN
SELECT State, Condition
INTO v_state, v_condition
FROM Inventory
WHERE ID = p_inventory_id;
IF NOT FOUND THEN
        RAISE EXCEPTION 'Инвентарь с ID % не найден', p_inventory_id;
END IF;
SELECT EXISTS (
    SELECT 1 FROM InStock WHERE SpotID = p_spot_id AND InventoryID = p_inventory_id
) INTO v_in_stock;
IF NOT v_in_stock THEN
        RAISE EXCEPTION 'Инвентарь с ID % не числится на точке проката %', p_inventory_id, p_spot_id;
END IF;
    IF v_condition = 'damaged' THEN
        RAISE EXCEPTION 'Инвентарь с ID % поврежден (damaged) и не может быть выдан', p_inventory_id;
END IF;
    IF v_state NOT IN ('available', 'booked') THEN
        RAISE EXCEPTION 'Инвентарь с ID % недоступен для выдачи (текущий статус: %)', p_inventory_id, v_state;
END IF;
SELECT EXISTS (
    SELECT 1
    FROM Booking
    WHERE InventoryID = p_inventory_id
      AND ClientID <> p_client_id
      AND BookingStart < (CURRENT_TIMESTAMP + p_duration + INTERVAL '20 minutes')
      AND (BookingEnd + INTERVAL '20 minutes') > CURRENT_TIMESTAMP
) INTO v_other_booking_exists;
IF v_other_booking_exists THEN
        RAISE EXCEPTION 'Инвентарь с ID % забронирован другим клиентом на пересекающееся время', p_inventory_id;
END IF;
SELECT ID INTO v_client_booking_id
FROM Booking
WHERE InventoryID = p_inventory_id
  AND ClientID = p_client_id
  AND BookingStart <= (CURRENT_TIMESTAMP + INTERVAL '1 hour')
  AND BookingEnd >= CURRENT_TIMESTAMP
ORDER BY BookingStart ASC
    LIMIT 1;
IF v_client_booking_id IS NOT NULL THEN
DELETE FROM Booking WHERE ID = v_client_booking_id;
ELSIF v_state = 'booked' THEN
        RAISE EXCEPTION 'Инвентарь имеет статус booked, но подходящая бронь для клиента % не найдена', p_client_id;
END IF;
INSERT INTO Rent (ClientID, InventoryID, EmployeeID, SpotID, Duration, State, Date)
VALUES (p_client_id, p_inventory_id, p_employee_id, p_spot_id, p_duration, 'active', CURRENT_DATE);
UPDATE Inventory
SET State = 'rented'
WHERE ID = p_inventory_id;
END;
$$;