CREATE INDEX idx_inventory_type_size_state ON Inventory (Type, Size, State) WHERE Condition <> 'damaged';
CREATE INDEX idx_rent_active_inventory ON Rent (InventoryID, SpotID, Date) WHERE State = 'active';
CREATE INDEX idx_inventory_needs_repair ON Inventory (Type, ID) WHERE State = 'needs_repair';
