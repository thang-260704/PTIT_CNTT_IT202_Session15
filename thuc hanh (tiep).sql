
USE mini_social_network;

CREATE TABLE IF NOT EXISTS User_Log (
    log_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT,
    action VARCHAR(100) NOT NULL,
    log_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id),
    INDEX idx_action (action)
);

DROP PROCEDURE IF EXISTS sp_register_user_v2;
DELIMITER //
CREATE PROCEDURE sp_register_user_v2(
    IN p_username VARCHAR(50),
    IN p_password VARCHAR(255),
    IN p_email VARCHAR(100),
    OUT p_user_id INT,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_message = 'LỖI: Không thể đăng ký người dùng';
        SET p_user_id = -1;
    END;
    
    START TRANSACTION;
    
    IF p_username IS NULL OR TRIM(p_username) = '' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Username không được để trống';
    END IF;
    
    IF p_email IS NULL OR TRIM(p_email) = '' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Email không được để trống';
    END IF;
    
    IF EXISTS (SELECT 1 FROM Users WHERE username = p_username) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Username đã tồn tại trong hệ thống';
    END IF;
    
    IF EXISTS (SELECT 1 FROM Users WHERE email = p_email) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Email đã được đăng ký';
    END IF;
    
    INSERT INTO Users (username, password, email)
    VALUES (p_username, p_password, p_email);
    
    SET p_user_id = LAST_INSERT_ID();
    SET p_message = 'Đăng ký thành công';
    
    COMMIT;
END//
DELIMITER ;

DROP TRIGGER IF EXISTS trg_after_user_register;
DELIMITER //
CREATE TRIGGER trg_after_user_register
AFTER INSERT ON Users
FOR EACH ROW
BEGIN
    INSERT INTO User_Log (user_id, action)
    VALUES (NEW.user_id, 'USER_REGISTERED');
END//
DELIMITER ;

SELECT '========== DEMO BÀI 1: ĐĂNG KÝ THÀNH VIÊN ==========' AS '';

SELECT '--- Test 1.1: Đăng ký user thành công ---' AS '';
CALL sp_register_user_v2('user_test1', 'password123', 'test1@email.com', @uid, @msg);
SELECT @uid AS user_id, @msg AS message;

CALL sp_register_user_v2('user_test2', 'password123', 'test2@email.com', @uid, @msg);
SELECT @uid AS user_id, @msg AS message;

CALL sp_register_user_v2('user_test3', 'password123', 'test3@email.com', @uid, @msg);
SELECT @uid AS user_id, @msg AS message;

SELECT '--- Danh sách Users vừa tạo ---' AS '';
SELECT user_id, username, email, created_at 
FROM Users 
WHERE username LIKE 'user_test%'
ORDER BY user_id;

SELECT '--- Log đăng ký ---' AS '';
SELECT * FROM User_Log ORDER BY log_time DESC LIMIT 3;

SELECT '--- Test 1.2: Đăng ký trùng username (FAIL) ---' AS '';
CALL sp_register_user_v2('user_test1', 'password456', 'new@email.com', @uid, @msg);
SELECT @uid AS user_id, @msg AS message;

SELECT '--- Test 1.3: Đăng ký trùng email (FAIL) ---' AS '';
CALL sp_register_user_v2('user_test4', 'password123', 'test1@email.com', @uid, @msg);
SELECT @uid AS user_id, @msg AS message;

SELECT '--- Test 1.4: Username rỗng (FAIL) ---' AS '';
CALL sp_register_user_v2('', 'password123', 'empty@email.com', @uid, @msg);
SELECT @uid AS user_id, @msg AS message;

CREATE TABLE IF NOT EXISTS Post_Log (
    log_id INT PRIMARY KEY AUTO_INCREMENT,
    post_id INT,
    user_id INT,
    action VARCHAR(100) NOT NULL,
    log_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (post_id) REFERENCES Posts(post_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE,
    INDEX idx_post_id (post_id),
    INDEX idx_user_id (user_id)
);

DROP PROCEDURE IF EXISTS sp_create_post_v2;
DELIMITER //
CREATE PROCEDURE sp_create_post_v2(
    IN p_user_id INT,
    IN p_content TEXT,
    OUT p_post_id INT,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_message = 'LỖI: Không thể tạo bài viết';
        SET p_post_id = -1;
    END;
    
    START TRANSACTION;
    
    IF NOT EXISTS (SELECT 1 FROM Users WHERE user_id = p_user_id) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'User không tồn tại';
    END IF;
    
    IF p_content IS NULL OR TRIM(p_content) = '' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Nội dung bài viết không được để trống';
    END IF;
    
    IF CHAR_LENGTH(p_content) > 5000 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Nội dung bài viết quá dài (tối đa 5000 ký tự)';
    END IF;
    
    INSERT INTO Posts (user_id, content)
    VALUES (p_user_id, p_content);
    
    SET p_post_id = LAST_INSERT_ID();
    SET p_message = 'Tạo bài viết thành công';
    
    COMMIT;
END//
DELIMITER ;

DROP TRIGGER IF EXISTS trg_after_post_create;
DELIMITER //
CREATE TRIGGER trg_after_post_create
AFTER INSERT ON Posts
FOR EACH ROW
BEGIN
    INSERT INTO Post_Log (post_id, user_id, action)
    VALUES (NEW.post_id, NEW.user_id, 'POST_CREATED');
END//
DELIMITER ;

SELECT '========== DEMO BÀI 2: ĐĂNG BÀI VIẾT ==========' AS '';
SELECT '--- Test 2.1: Tạo bài viết thành công ---' AS '';
CALL sp_create_post_v2(1, 'Đây là bài viết test số 1', @pid, @msg);
SELECT @pid AS post_id, @msg AS message;

CALL sp_create_post_v2(1, 'Hôm nay thời tiết đẹp quá!', @pid, @msg);
SELECT @pid AS post_id, @msg AS message;

CALL sp_create_post_v2(2, 'Chia sẻ một số kinh nghiệm học MySQL...', @pid, @msg);
SELECT @pid AS post_id, @msg AS message;

CALL sp_create_post_v2(3, 'Vừa hoàn thành dự án mới! 🎉', @pid, @msg);
SELECT @pid AS post_id, @msg AS message;

CALL sp_create_post_v2(2, 'Đang tìm hiểu về Database Triggers', @pid, @msg);
SELECT @pid AS post_id, @msg AS message;
SELECT '--- Danh sách Posts vừa tạo ---' AS '';
SELECT p.post_id, u.username, LEFT(p.content, 50) AS content_preview, 
       p.like_count, p.comment_count, p.created_at
FROM Posts p
JOIN Users u ON p.user_id = u.user_id
ORDER BY p.created_at DESC
LIMIT 5;

SELECT '--- Log tạo bài viết ---' AS '';
SELECT * FROM Post_Log ORDER BY log_time DESC LIMIT 5;

SELECT '--- Test 2.2: Content rỗng (FAIL) ---' AS '';
CALL sp_create_post_v2(1, '', @pid, @msg);
SELECT @pid AS post_id, @msg AS message;

SELECT '--- Test 2.3: User không tồn tại (FAIL) ---' AS '';
CALL sp_create_post_v2(9999, 'Test content', @pid, @msg);
SELECT @pid AS post_id, @msg AS message;

DROP TRIGGER IF EXISTS trg_after_like_insert_v2;
DELIMITER //
CREATE TRIGGER trg_after_like_insert_v2
AFTER INSERT ON Likes
FOR EACH ROW
BEGIN
    UPDATE Posts 
    SET like_count = like_count + 1 
    WHERE post_id = NEW.post_id;
    
    INSERT INTO Post_Log (post_id, user_id, action)
    VALUES (NEW.post_id, NEW.user_id, 'POST_LIKED');
END//
DELIMITER ;

DROP TRIGGER IF EXISTS trg_after_like_delete_v2;
DELIMITER //
CREATE TRIGGER trg_after_like_delete_v2
AFTER DELETE ON Likes
FOR EACH ROW
BEGIN
    UPDATE Posts 
    SET like_count = like_count - 1 
    WHERE post_id = OLD.post_id;
    
    INSERT INTO Post_Log (post_id, user_id, action)
    VALUES (OLD.post_id, OLD.user_id, 'POST_UNLIKED');
END//
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_like_post_v2;
DELIMITER //
CREATE PROCEDURE sp_like_post_v2(
    IN p_user_id INT,
    IN p_post_id INT,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_message = 'LỖI: Không thể thích bài viết';
    END;
    
    START TRANSACTION;
    
    IF NOT EXISTS (SELECT 1 FROM Posts WHERE post_id = p_post_id) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Bài viết không tồn tại';
    END IF;
    
    IF EXISTS (SELECT 1 FROM Likes WHERE user_id = p_user_id AND post_id = p_post_id) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Bạn đã thích bài viết này rồi';
    END IF;
    
    INSERT INTO Likes (user_id, post_id)
    VALUES (p_user_id, p_post_id);
    
    SET p_message = 'Thích bài viết thành công';
    COMMIT;
END//
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_unlike_post_v2;
DELIMITER //
CREATE PROCEDURE sp_unlike_post_v2(
    IN p_user_id INT,
    IN p_post_id INT,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_message = 'LỖI: Không thể bỏ thích bài viết';
    END;
    
    START TRANSACTION;
    
    IF NOT EXISTS (SELECT 1 FROM Likes WHERE user_id = p_user_id AND post_id = p_post_id) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Bạn chưa thích bài viết này';
    END IF;
    
    DELETE FROM Likes 
    WHERE user_id = p_user_id AND post_id = p_post_id;
    
    SET p_message = 'Bỏ thích thành công';
    COMMIT;
END//
DELIMITER ;

SELECT '========== DEMO BÀI 3: THÍCH BÀI VIẾT ==========' AS '';

SET @test_post_id = (SELECT post_id FROM Posts LIMIT 1);

SELECT '--- Test 3.1: Thích bài viết ---' AS '';
SELECT CONCAT('Post ID để test: ', @test_post_id) AS info;

SELECT post_id, like_count FROM Posts WHERE post_id = @test_post_id;

CALL sp_like_post_v2(1, @test_post_id, @msg);
SELECT @msg AS message;

CALL sp_like_post_v2(2, @test_post_id, @msg);
SELECT @msg AS message;

CALL sp_like_post_v2(3, @test_post_id, @msg);
SELECT @msg AS message;

SELECT '--- Like count sau khi 3 users thích ---' AS '';
SELECT post_id, like_count FROM Posts WHERE post_id = @test_post_id;

SELECT '--- Test 3.2: Thích trùng (FAIL) ---' AS '';
CALL sp_like_post_v2(1, @test_post_id, @msg);
SELECT @msg AS message;

SELECT '--- Test 3.3: Bỏ thích ---' AS '';
CALL sp_unlike_post_v2(2, @test_post_id, @msg);
SELECT @msg AS message;

SELECT '--- Like count sau khi 1 user bỏ thích ---' AS '';
SELECT post_id, like_count FROM Posts WHERE post_id = @test_post_id;

SELECT '--- Test 3.4: Bỏ thích khi chưa thích (FAIL) ---' AS '';
CALL sp_unlike_post_v2(5, @test_post_id, @msg);
SELECT @msg AS message;

SELECT '--- Log hoạt động Like/Unlike ---' AS '';
SELECT * FROM Post_Log 
WHERE action IN ('POST_LIKED', 'POST_UNLIKED')
ORDER BY log_time DESC 
LIMIT 5;

DROP PROCEDURE IF EXISTS sp_send_friend_request_v2;
DELIMITER //
CREATE PROCEDURE sp_send_friend_request_v2(
    IN p_sender_id INT,
    IN p_receiver_id INT,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_message = 'LỖI: Không thể gửi lời mời kết bạn';
    END;
    
    START TRANSACTION;
    
    IF p_sender_id = p_receiver_id THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Không thể gửi lời mời kết bạn cho chính mình';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM Users WHERE user_id = p_receiver_id) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Người nhận không tồn tại';
    END IF;
    
    IF EXISTS (SELECT 1 FROM Friends 
               WHERE user_id = p_sender_id AND friend_id = p_receiver_id) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Bạn đã gửi lời mời cho người này rồi';
    END IF;
    
    IF EXISTS (SELECT 1 FROM Friends 
               WHERE user_id = p_receiver_id AND friend_id = p_sender_id) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Người này đã gửi lời mời cho bạn, hãy chấp nhận';
    END IF;
    
    INSERT INTO Friends (user_id, friend_id, status)
    VALUES (p_sender_id, p_receiver_id, 'pending');
    
    SET p_message = 'Gửi lời mời kết bạn thành công';
    COMMIT;
END//
DELIMITER ;

DROP TRIGGER IF EXISTS trg_after_friend_request;
DELIMITER //
CREATE TRIGGER trg_after_friend_request
AFTER INSERT ON Friends
FOR EACH ROW
BEGIN
    INSERT INTO User_Log (user_id, action)
    VALUES (NEW.user_id, CONCAT('FRIEND_REQUEST_SENT to user_id=', NEW.friend_id));
    
    INSERT INTO User_Log (user_id, action)
    VALUES (NEW.friend_id, CONCAT('FRIEND_REQUEST_RECEIVED from user_id=', NEW.user_id));
END//
DELIMITER ;

SELECT '========== DEMO BÀI 4: GỬI LỜI MỜI KẾT BẠN ==========' AS '';

SELECT '--- Test 4.1: Gửi lời mời hợp lệ ---' AS '';
CALL sp_send_friend_request_v2(1, 2, @msg);
SELECT @msg AS message;

CALL sp_send_friend_request_v2(1, 3, @msg);
SELECT @msg AS message;

CALL sp_send_friend_request_v2(2, 3, @msg);
SELECT @msg AS message;

SELECT '--- Danh sách lời mời vừa gửi ---' AS '';
SELECT f.user_id AS sender, f.friend_id AS receiver, f.status, f.created_at
FROM Friends f
WHERE f.status = 'pending'
ORDER BY f.created_at DESC
LIMIT 3;

SELECT '--- Test 4.2: Tự gửi cho mình (FAIL) ---' AS '';
CALL sp_send_friend_request_v2(1, 1, @msg);
SELECT @msg AS message;

SELECT '--- Test 4.3: Gửi lời mời trùng (FAIL) ---' AS '';
CALL sp_send_friend_request_v2(1, 2, @msg);
SELECT @msg AS message;

SELECT '--- Test 4.4: Người nhận không tồn tại (FAIL) ---' AS '';
CALL sp_send_friend_request_v2(1, 9999, @msg);
SELECT @msg AS message;

SELECT '--- Log gửi lời mời ---' AS '';
SELECT * FROM User_Log 
WHERE action LIKE 'FRIEND_REQUEST%'
ORDER BY log_time DESC 
LIMIT 6;

DROP PROCEDURE IF EXISTS sp_accept_friend_request_v2;
DELIMITER //
CREATE PROCEDURE sp_accept_friend_request_v2(
    IN p_receiver_id INT,
    IN p_sender_id INT,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_message = 'LỖI: Không thể chấp nhận lời mời';
    END;
    
    START TRANSACTION;
    
    IF NOT EXISTS (SELECT 1 FROM Friends 
                   WHERE user_id = p_sender_id 
                   AND friend_id = p_receiver_id 
                   AND status = 'pending') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Không tìm thấy lời mời kết bạn đang chờ';
    END IF;
    
    UPDATE Friends 
    SET status = 'accepted'
    WHERE user_id = p_sender_id AND friend_id = p_receiver_id;
    
    INSERT INTO Friends (user_id, friend_id, status)
    VALUES (p_receiver_id, p_sender_id, 'accepted');
    
    INSERT INTO User_Log (user_id, action)
    VALUES (p_receiver_id, CONCAT('FRIEND_REQUEST_ACCEPTED from user_id=', p_sender_id));
    
    INSERT INTO User_Log (user_id, action)
    VALUES (p_sender_id, CONCAT('FRIEND_REQUEST_ACCEPTED by user_id=', p_receiver_id));
    
    SET p_message = 'Chấp nhận kết bạn thành công';
    COMMIT;
END//
DELIMITER ;

SELECT '========== DEMO BÀI 5: CHẤP NHẬN KẾT BẠN ==========' AS '';

SELECT '--- Lời mời đang chờ ---' AS '';
SELECT f.user_id AS sender, f.friend_id AS receiver, f.status
FROM Friends f
WHERE f.status = 'pending';

SELECT '--- Test 5.1: Chấp nhận lời mời ---' AS '';
CALL sp_accept_friend_request_v2(2, 1, @msg);
SELECT @msg AS message;

CALL sp_accept_friend_request_v2(3, 1, @msg);
SELECT @msg AS message;

SELECT '--- Quan hệ bạn bè sau khi chấp nhận (đối xứng) ---' AS '';
SELECT user_id, friend_id, status, created_at
FROM Friends
WHERE (user_id IN (1,2,3) OR friend_id IN (1,2,3))
AND status = 'accepted'
ORDER BY user_id, friend_id;

SELECT '--- Test 5.2: Chấp nhận lời mời không tồn tại (FAIL) ---' AS '';
CALL sp_accept_friend_request_v2(1, 999, @msg);
SELECT @msg AS message;

-- Xem log
SELECT '--- Log chấp nhận kết bạn ---' AS '';
SELECT * FROM User_Log 
WHERE action LIKE '%ACCEPTED%'
ORDER BY log_time DESC 
LIMIT 4;

DROP PROCEDURE IF EXISTS sp_unfriend;
DELIMITER //
CREATE PROCEDURE sp_unfriend(
    IN p_user_id INT,
    IN p_friend_id INT,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE v_count INT DEFAULT 0;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_message = 'LỖI: Không thể hủy kết bạn';
    END;
    
    START TRANSACTION;
    
    SELECT COUNT(*) INTO v_count
    FROM Friends
    WHERE (user_id = p_user_id AND friend_id = p_friend_id AND status = 'accepted')
       OR (user_id = p_friend_id AND friend_id = p_user_id AND status = 'accepted');
    
    IF v_count = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Không tìm thấy quan hệ bạn bè';
    END IF;
    
    DELETE FROM Friends
    WHERE (user_id = p_user_id AND friend_id = p_friend_id)
       OR (user_id = p_friend_id AND friend_id = p_user_id);
    
    INSERT INTO User_Log (user_id, action)
    VALUES (p_user_id, CONCAT('UNFRIEND user_id=', p_friend_id));
    
    INSERT INTO User_Log (user_id, action)
    VALUES (p_friend_id, CONCAT('UNFRIEND by user_id=', p_user_id));
    
    SET p_message = 'Hủy kết bạn thành công';
    COMMIT;
END//
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_reject_friend_request;
DELIMITER //
CREATE PROCEDURE sp_reject_friend_request(
    IN p_receiver_id INT,
    IN p_sender_id INT,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_message = 'LỖI: Không thể từ chối lời mời';
    END;
    
    START TRANSACTION;
    
    IF NOT EXISTS (SELECT 1 FROM Friends