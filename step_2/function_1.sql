CREATE OR REPLACE FUNCTION get_available_inventory(
    p_spot_id BIGINT,
    p_type_id BIGINT,
    p_size REAL,
    p_start TIMESTAMP,
    p_end TIMESTAMP,
    p_service_buffer INTERVAL DEFAULT INTERVAL '20 minutes'
)
RETURNS TABLE (
    inventory_id BIGINT,
    condition inventory_condition_enum,
    booking_percent REAL,
    spot_price REAL
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_end <= p_start THEN
        RAISE EXCEPTION 'Время окончания бронирования (%) должно быть позже времени начала (%)', p_end, p_start;
END IF;
RETURN QUERY
SELECT
    i.ID,
    i.Condition,
    i.BookingPercent,
    p.Price
FROM Inventory i
         JOIN InStock s ON s.InventoryID = i.ID
         LEFT JOIN Pricing p ON p.InventoryID = i.ID AND p.SpotID = s.SpotID
WHERE s.SpotID = p_spot_id
  AND i.Type = p_type_id
  AND i.Size = p_size
  AND i.State IN ('available', 'booked')
  AND i.Condition <> 'damaged'
  AND NOT EXISTS (
    SELECT 1
    FROM Booking b
    WHERE b.InventoryID = i.ID
      AND b.BookingStart < (p_end + p_service_buffer)
      AND (b.BookingEnd + p_service_buffer) > p_start
);
END;
$$;
