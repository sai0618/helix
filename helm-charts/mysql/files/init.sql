CREATE TABLE IF NOT EXISTS user_info (
  id CHAR(36) PRIMARY KEY,
  first_name VARCHAR(80) NOT NULL,
  last_name VARCHAR(80) NOT NULL,
  email VARCHAR(255) NOT NULL UNIQUE,
  role VARCHAR(80) NOT NULL DEFAULT 'user',
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS user_credentials (
  user_id CHAR(36) PRIMARY KEY,
  username VARCHAR(80) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_user_credentials_user_info
    FOREIGN KEY (user_id) REFERENCES user_info(id)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO user_info (id, first_name, last_name, email, role, active)
VALUES
  ('11111111-1111-1111-1111-111111111111', 'Ada', 'Lovelace', 'ada.lovelace@example.com', 'admin', TRUE),
  ('22222222-2222-2222-2222-222222222222', 'Grace', 'Hopper', 'grace.hopper@example.com', 'developer', TRUE),
  ('33333333-3333-3333-3333-333333333333', 'Katherine', 'Johnson', 'katherine.johnson@example.com', 'analyst', TRUE)
ON DUPLICATE KEY UPDATE
  first_name = VALUES(first_name),
  last_name = VALUES(last_name),
  role = VALUES(role),
  active = VALUES(active);

INSERT INTO user_credentials (user_id, username, password_hash)
VALUES
  ('11111111-1111-1111-1111-111111111111', 'ada', 'scrypt:32768:8:1$b3bM6AOAcuuMagCP$0a8de9efe7f7244282d7220ba6e70fc9b23ba6ce7a7ef149e382395fd8468bf194f45b4d90ac55bdf464bfac0119ef18da528fa58b60153aace193d08e0069cc'),
  ('22222222-2222-2222-2222-222222222222', 'grace', 'scrypt:32768:8:1$rF9BEhtO3ePHgUiu$03d9fc7bb07a88939070149c4c9cfdc519333fa1606ab162642689198fe3f085791ed2c935607a321c37a5574941518ef360ae4d9377ee37aed910b70d8d24d5'),
  ('33333333-3333-3333-3333-333333333333', 'katherine', 'scrypt:32768:8:1$kP0qyyhhwaygi5Z4$fa6ced56e04b7ba330ee96699403af33e3aefc3fb11f847c3afec1d8a88b0493cb98b0634d0a8994dbd6474eddb385439e98e4228bc4c461f65e3a083f89ead6')
ON DUPLICATE KEY UPDATE
  username = VALUES(username),
  password_hash = VALUES(password_hash);
