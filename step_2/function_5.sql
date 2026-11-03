CREATE OR REPLACE PROCEDURE register_inventory_purchase(
    p_type_id BIGINT,
    p_size REAL,
    p_booking_percent REAL,
    p_purchase_price REAL,
    p_source VARCHAR(255),
    p_spot_id BIGINT DEFAULT NULL,          -- На какую точку сразу поставить на баланс
    p_rental_price REAL DEFAULT NULL,       -- Тариф проката на этой точке
    INOUT o_inventory_id BIGINT DEFAULT NULL,
    INOUT o_purchase_id BIGINT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
INSERT INTO Inventory (Type, Size, State, Condition, BookingPercent)
VALUES (p_type_id, p_size, 'available', 'good', p_booking_percent)
    RETURNING ID INTO o_inventory_id;
INSERT INTO Purchase (InventoryID, TypeID, Price, Source, Date)
VALUES (o_inventory_id, p_type_id, p_purchase_price, p_source, CURRENT_DATE)
    RETURNING ID INTO o_purchase_id;
IF p_spot_id IS NOT NULL THEN
        INSERT INTO InStock (SpotID, InventoryID)
        VALUES (p_spot_id, o_inventory_id);
        IF p_rental_price IS NOT NULL THEN
            INSERT INTO Pricing (InventoryID, SpotID, Price)
            VALUES (o_inventory_id, p_spot_id, p_rental_price);
END IF;
END IF;
END;
$$;