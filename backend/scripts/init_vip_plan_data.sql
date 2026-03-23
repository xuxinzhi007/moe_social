INSERT INTO `vip_plans` (`name`, `price`, `duration`, `features`, `created_at`, `updated_at`)
VALUES
  ('月度VIP', 99.00, 30, '月卡测试套餐', NOW(3), NOW(3)),
  ('季度VIP', 268.00, 90, '季度测试套餐', NOW(3), NOW(3)),
  ('年度VIP', 899.00, 365, '年度测试套餐', NOW(3), NOW(3))
ON DUPLICATE KEY UPDATE
  `price` = VALUES(`price`),
  `duration` = VALUES(`duration`),
  `features` = VALUES(`features`),
  `updated_at` = VALUES(`updated_at`);
