CREATE OR REPLACE PROCEDURE return_inventory_from_rent(
    p_rent_id BIGINT,
    p_is_damaged BOOLEAN DEFAULT FALSE
)
LANGUAGE plpgsql
AS $$
DECLARE
v_inventory_id BIGINT;
    v_rent_state rent_state_enum;
    v_has_future_bookings BOOLEAN;
BEGIN
SELECT InventoryID, State
INTO v_inventory_id, v_rent_state
FROM Rent
WHERE ID = p_rent_id
    FOR UPDATE;
IF NOT FOUND THEN
        RAISE EXCEPTION 'Аренда с ID % не найдена', p_rent_id;
END IF;
    IF v_rent_state = 'completed' THEN
        RAISE EXCEPTION 'Аренда с ID % уже закрыта', p_rent_id;
END IF;
UPDATE Rent
SET State = 'completed'
WHERE ID = p_rent_id;
IF v_inventory_id IS NOT NULL THEN
        IF p_is_damaged THEN
UPDATE Inventory
SET Condition = 'damaged',
    State = 'needs_repair'
WHERE ID = v_inventory_id;
ELSE
SELECT EXISTS (
    SELECT 1 FROM Booking
    WHERE InventoryID = v_inventory_id
      AND BookingEnd > CURRENT_TIMESTAMP
) INTO v_has_future_bookings;
UPDATE Inventory
SET State = CASE WHEN v_has_future_bookings THEN 'booked'::inventory_state_enum ELSE 'available'::inventory_state_enum END
WHERE ID = v_inventory_id;
END IF;
END IF;
END;
$$;