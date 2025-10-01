-- Insert vozaci data from CSV
INSERT INTO vozaci (id, ime, broj_telefona, email, aktivan, boja, created_at, updated_at) VALUES
('504c565d-8160-4adc-a6db-9f8e113de0e3', 'Svetlana', NULL, NULL, true, '#FF1493', '2025-09-30 17:13:25.82528+00', '2025-09-30 17:13:25.82528+00'),
('a19b81cb-3e7d-44ea-aa78-237b082640c8', 'Bruda', NULL, NULL, true, '#7C4DFF', '2025-09-30 17:13:25.82528+00', '2025-09-30 17:13:25.82528+00'),
('b8b1a2fa-8c32-4011-a19e-f8938cacb29f', 'Bojan', NULL, NULL, true, '#00E5FF', '2025-09-30 17:13:25.82528+00', '2025-09-30 17:13:25.82528+00'),
('cd818dd0-b47b-4db1-bbaa-7086d59476d9', 'Bilevski', NULL, NULL, true, '#FF9800', '2025-09-30 17:13:25.82528+00', '2025-09-30 17:13:25.82528+00')
ON CONFLICT (id) DO NOTHING;