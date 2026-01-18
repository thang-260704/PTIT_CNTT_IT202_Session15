-- ========================================
-- MINI SOCIAL NETWORK DATABASE
-- Database Centric Project

DROP DATABASE IF EXISTS mini_social_network;
CREATE DATABASE mini_social_network CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE mini_social_network;

CREATE TABLE Users (
    user_id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_username (username),
    INDEX idx_email (email)
);

-- Bảng Posts
CREATE TABLE Posts (
    post_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    content TEXT NOT NULL,
    like_count INT DEFAULT 0,
    comment_count INT DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id),
    INDEX idx_created_at (created_at)
);

CREATE TABLE Comments (
    comment_id INT PRIMARY KEY AUTO_INCREMENT,
    post_id INT NOT NULL,
    user_id INT NOT NULL,
    content TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (post_id) REFERENCES Posts(post_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE,
    INDEX idx_post_id (post_id),
    INDEX idx_user_id (user_id)
);

CREATE TABLE Likes (
    user_id INT NOT NULL,
    post_id INT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, post_id),
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (post_id) REFERENCES Posts(post_id) ON DELETE CASCADE,
    INDEX idx_post_id (post_id)
);

CREATE TABLE Friends (
    user_id INT NOT NULL,
    friend_id INT NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, friend_id),
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (friend_id) REFERENCES Users(user_id) ON DELETE CASCADE,
    CONSTRAINT chk_status CHECK (status IN ('pending', 'accepted')),
    CONSTRAINT chk_not_self CHECK (user_id != friend_id),
    INDEX idx_friend_id (friend_id),
    INDEX idx_status (status)
);

CREATE TABLE Notifications (
    notification_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    type VARCHAR(50) NOT NULL,
    content VARCHAR(255) NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id),
    INDEX idx_is_read (is_read)
);

CREATE TABLE Activity_Logs (
    log_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT,
    action VARCHAR(100) NOT NULL,
    table_name VARCHAR(50),
    record_id INT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE SET NULL,
    INDEX idx_user_id (user_id),
    INDEX idx_created_at (created_at)
);

DELIMITER //
CREATE TRIGGER trg_after_like_insert
AFTER INSERT ON Likes
FOR EACH ROW
BEGIN
    UPDATE Posts 
    SET like_count = like_count + 1 
    WHERE post_id = NEW.post_id;
    
    INSERT INTO Notifications (user_id, type, content)
    SELECT user_id, 'like', CONCAT('Ai đó đã thích bài viết của bạn')
    FROM Posts WHERE post_id = NEW.post_id AND user_id != NEW.user_id;
END//
DELIMITER ;

DELIMITER //
CREATE TRIGGER trg_after_like_delete
AFTER DELETE ON Likes
FOR EACH ROW
BEGIN
    UPDATE Posts 
    SET like_count = like_count - 1 
    WHERE post_id = OLD.post_id;
END//
DELIMITER ;

DELIMITER //
CREATE TRIGGER trg_after_comment_insert
AFTER INSERT ON Comments
FOR EACH ROW
BEGIN
    UPDATE Posts 
    SET comment_count = comment_count + 1 
    WHERE post_id = NEW.post_id;
    
    INSERT INTO Notifications (user_id, type, content)
    SELECT user_id, 'comment', CONCAT('Ai đó đã bình luận bài viết của bạn')
    FROM Posts WHERE post_id = NEW.post_id AND user_id != NEW.user_id;
END//
DELIMITER ;

DELIMITER //
CREATE TRIGGER trg_after_comment_delete
AFTER DELETE ON Comments
FOR EACH ROW
BEGIN
    UPDATE Posts 
    SET comment_count = comment_count - 1 
    WHERE post_id = OLD.post_id;
END//
DELIMITER ;

DELIMITER //
CREATE TRIGGER trg_before_friend_insert
BEFORE INSERT ON Friends
FOR EACH ROW
BEGIN
    IF NEW.user_id = NEW.friend_id THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Không thể kết bạn với chính mình';
    END IF;
    
    IF EXISTS (SELECT 1 FROM Friends WHERE user_id = NEW.friend_id AND friend_id = NEW.user_id) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Quan hệ bạn bè đã tồn tại';
    END IF;
END//
DELIMITER ;

DELIMITER //
CREATE TRIGGER trg_after_friend_insert
AFTER INSERT ON Friends
FOR EACH ROW
BEGIN
    IF NEW.status = 'pending' THEN
        INSERT INTO Notifications (user_id, type, content)
        VALUES (NEW.friend_id, 'friend_request', 'Bạn có lời mời kết bạn mới');
    END IF;
END//
DELIMITER ;

DELIMITER //
CREATE TRIGGER trg_after_post_insert
AFTER INSERT ON Posts
FOR EACH ROW
BEGIN
    INSERT INTO Activity_Logs (user_id, action, table_name, record_id)
    VALUES (NEW.user_id, 'CREATE_POST', 'Posts', NEW.post_id);
END//
DELIMITER ;

DELIMITER //
CREATE TRIGGER trg_before_post_delete
BEFORE DELETE ON Posts
FOR EACH ROW
BEGIN
    INSERT INTO Activity_Logs (user_id, action, table_name, record_id)
    VALUES (OLD.user_id, 'DELETE_POST', 'Posts', OLD.post_id);
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_register_user(
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
        SET p_message = 'Lỗi: Không thể đăng ký người dùng';
        SET p_user_id = -1;
    END;
    
    START TRANSACTION;
    
    IF EXISTS (SELECT 1 FROM Users WHERE username = p_username) THEN
        SET p_message = 'Username đã tồn tại';
        SET p_user_id = -1;
        ROLLBACK;
    ELSEIF EXISTS (SELECT 1 FROM Users WHERE email = p_email) THEN
        SET p_message = 'Email đã tồn tại';
        SET p_user_id = -1;
        ROLLBACK;
    ELSE
        INSERT INTO Users (username, password, email)
        VALUES (p_username, p_password, p_email);
        
        SET p_user_id = LAST_INSERT_ID();
        SET p_message = 'Đăng ký thành công';
        COMMIT;
    END IF;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_create_post(
    IN p_user_id INT,
    IN p_content TEXT,
    OUT p_post_id INT,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_message = 'Lỗi: Không thể tạo bài viết';
        SET p_post_id = -1;
    END;
    
    START TRANSACTION;
    
    IF NOT EXISTS (SELECT 1 FROM Users WHERE user_id = p_user_id) THEN
        SET p_message = 'User không tồn tại';
        SET p_post_id = -1;
        ROLLBACK;
    ELSE
        INSERT INTO Posts (user_id, content)
        VALUES (p_user_id, p_content);
        
        SET p_post_id = LAST_INSERT_ID();
        SET p_message = 'Tạo bài viết thành công';
        COMMIT;
    END IF;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_like_post(
    IN p_user_id INT,
    IN p_post_id INT,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_message = 'Lỗi: Không thể thích bài viết';
    END;
    
    START TRANSACTION;
    
    IF EXISTS (SELECT 1 FROM Likes WHERE user_id = p_user_id AND post_id = p_post_id) THEN
        SET p_message = 'Bạn đã thích bài viết này rồi';
        ROLLBACK;
    ELSEIF NOT EXISTS (SELECT 1 FROM Posts WHERE post_id = p_post_id) THEN
        SET p_message = 'Bài viết không tồn tại';
        ROLLBACK;
    ELSE
        INSERT INTO Likes (user_id, post_id)
        VALUES (p_user_id, p_post_id);
        
        SET p_message = 'Thích bài viết thành công';
        COMMIT;
    END IF;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_unlike_post(
    IN p_user_id INT,
    IN p_post_id INT,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_message = 'Lỗi: Không thể bỏ thích bài viết';
    END;
    
    START TRANSACTION;
    
    IF NOT EXISTS (SELECT 1 FROM Likes WHERE user_id = p_user_id AND post_id = p_post_id) THEN
        SET p_message = 'Bạn chưa thích bài viết này';
        ROLLBACK;
    ELSE
        DELETE FROM Likes 
        WHERE user_id = p_user_id AND post_id = p_post_id;
        
        SET p_message = 'Bỏ thích thành công';
        COMMIT;
    END IF;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_create_comment(
    IN p_user_id INT,
    IN p_post_id INT,
    IN p_content TEXT,
    OUT p_comment_id INT,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_message = 'Lỗi: Không thể tạo bình luận';
        SET p_comment_id = -1;
    END;
    
    START TRANSACTION;
    
    IF NOT EXISTS (SELECT 1 FROM Posts WHERE post_id = p_post_id) THEN
        SET p_message = 'Bài viết không tồn tại';
        SET p_comment_id = -1;
        ROLLBACK;
    ELSE
        INSERT INTO Comments (user_id, post_id, content)
        VALUES (p_user_id, p_post_id, p_content);
        
        SET p_comment_id = LAST_INSERT_ID();
        SET p_message = 'Bình luận thành công';
        COMMIT;
    END IF;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_send_friend_request(
    IN p_user_id INT,
    IN p_friend_id INT,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_message = 'Lỗi: Không thể gửi lời mời kết bạn';
    END;
    
    START TRANSACTION;
    
    IF p_user_id = p_friend_id THEN
        SET p_message = 'Không thể kết bạn với chính mình';
        ROLLBACK;
    ELSEIF NOT EXISTS (SELECT 1 FROM Users WHERE user_id = p_friend_id) THEN
        SET p_message = 'User không tồn tại';
        ROLLBACK;
    ELSEIF EXISTS (SELECT 1 FROM Friends WHERE user_id = p_user_id AND friend_id = p_friend_id) THEN
        SET p_message = 'Đã gửi lời mời trước đó';
        ROLLBACK;
    ELSEIF EXISTS (SELECT 1 FROM Friends WHERE user_id = p_friend_id AND friend_id = p_user_id) THEN
        SET p_message = 'Đã có lời mời từ người này';
        ROLLBACK;
    ELSE
        INSERT INTO Friends (user_id, friend_id, status)
        VALUES (p_user_id, p_friend_id, 'pending');
        
        SET p_message = 'Gửi lời mời kết bạn thành công';
        COMMIT;
    END IF;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_accept_friend_request(
    IN p_user_id INT,
    IN p_friend_id INT,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_message = 'Lỗi: Không thể chấp nhận lời mời';
    END;
    
    START TRANSACTION;
    
    IF NOT EXISTS (SELECT 1 FROM Friends 
                   WHERE user_id = p_friend_id 
                   AND friend_id = p_user_id 
                   AND status = 'pending') THEN
        SET p_message = 'Không tìm thấy lời mời kết bạn';
        ROLLBACK;
    ELSE
        UPDATE Friends 
        SET status = 'accepted'
        WHERE user_id = p_friend_id AND friend_id = p_user_id;
        
        INSERT INTO Notifications (user_id, type, content)
        VALUES (p_friend_id, 'friend_accepted', 'Lời mời kết bạn đã được chấp nhận');
        
        SET p_message = 'Chấp nhận kết bạn thành công';
        COMMIT;
    END IF;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_get_friends(
    IN p_user_id INT
)
BEGIN
    SELECT DISTINCT
        u.user_id,
        u.username,
        u.email,
        f.created_at AS friend_since
    FROM Users u
    INNER JOIN Friends f ON (
        (f.user_id = p_user_id AND f.friend_id = u.user_id) OR
        (f.friend_id = p_user_id AND f.user_id = u.user_id)
    )
    WHERE f.status = 'accepted'
    AND u.user_id != p_user_id
    ORDER BY f.created_at DESC;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_get_newsfeed(
    IN p_user_id INT,
    IN p_limit INT
)
BEGIN
    SELECT 
        p.post_id,
        p.user_id,
        u.username,
        p.content,
        p.like_count,
        p.comment_count,
        p.created_at,
        EXISTS(SELECT 1 FROM Likes WHERE user_id = p_user_id AND post_id = p.post_id) AS is_liked
    FROM Posts p
    INNER JOIN Users u ON p.user_id = u.user_id
    WHERE p.user_id IN (
        SELECT DISTINCT
            CASE 
                WHEN f.user_id = p_user_id THEN f.friend_id
                ELSE f.user_id
            END AS friend_user_id
        FROM Friends f
        WHERE (f.user_id = p_user_id OR f.friend_id = p_user_id)
        AND f.status = 'accepted'
    )
    OR p.user_id = p_user_id
    ORDER BY p.created_at DESC
    LIMIT p_limit;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_get_user_statistics(
    IN p_user_id INT
)
BEGIN
    SELECT 
        u.user_id,
        u.username,
        COUNT(DISTINCT p.post_id) AS total_posts,
        COUNT(DISTINCT c.comment_id) AS total_comments,
        COUNT(DISTINCT l.post_id) AS total_likes_given,
        (SELECT COUNT(*) FROM Likes WHERE post_id IN (SELECT post_id FROM Posts WHERE user_id = p_user_id)) AS total_likes_received,
        (SELECT COUNT(*) FROM Friends WHERE (user_id = p_user_id OR friend_id = p_user_id) AND status = 'accepted') AS total_friends
    FROM Users u
    LEFT JOIN Posts p ON u.user_id = p.user_id
    LEFT JOIN Comments c ON u.user_id = c.user_id
    LEFT JOIN Likes l ON u.user_id = l.user_id
    WHERE u.user_id = p_user_id
    GROUP BY u.user_id, u.username;
END//
DELIMITER ;

CALL sp_register_user('alice', 'password123', 'alice@email.com', @user_id, @msg);
CALL sp_register_user('bob', 'password123', 'bob@email.com', @user_id, @msg);
CALL sp_register_user('charlie', 'password123', 'charlie@email.com', @user_id, @msg);
CALL sp_register_user('diana', 'password123', 'diana@email.com', @user_id, @msg);
CALL sp_register_user('eve', 'password123', 'eve@email.com', @user_id, @msg);

CALL sp_create_post(1, 'Xin chào mọi người! Đây là bài viết đầu tiên của tôi.', @post_id, @msg);
CALL sp_create_post(2, 'Hôm nay thời tiết đẹp quá!', @post_id, @msg);
CALL sp_create_post(1, 'Đang học MySQL triggers và procedures, rất thú vị!', @post_id, @msg);
CALL sp_create_post(3, 'Chia sẻ một bài hát hay: ...', @post_id, @msg);
CALL sp_create_post(4, 'Vừa hoàn thành dự án mới!', @post_id, @msg);

CALL sp_create_comment(2, 1, 'Chào bạn Alice!', @comment_id, @msg);
CALL sp_create_comment(3, 1, 'Bài viết hay đấy!', @comment_id, @msg);
CALL sp_create_comment(1, 2, 'Đúng vậy, đi chơi thôi!', @comment_id, @msg);

CALL sp_like_post(2, 1, @msg);
CALL sp_like_post(3, 1, @msg);
CALL sp_like_post(4, 1, @msg);
CALL sp_like_post(1, 2, @msg);
CALL sp_like_post(3, 2, @msg);

CALL sp_send_friend_request(1, 2, @msg);
CALL sp_accept_friend_request(2, 1, @msg);

CALL sp_send_friend_request(1, 3, @msg);
CALL sp_accept_friend_request(3, 1, @msg);

CALL sp_send_friend_request(2, 3, @msg);
CALL sp_accept_friend_request(3, 2, @msg);

CALL sp_send_friend_request(4, 1, @msg);

CALL sp_get_user_statistics(1);

-- Xem newsfeed của Alice
CALL sp_get_newsfeed(1, 10);

CALL sp_get_friends(1);

SELECT * FROM Notifications ORDER BY created_at DESC;

SELECT * FROM Activity_Logs ORDER BY created_at DESC;

SELECT 
    p.post_id,
    u.username,
    p.content,
    p.like_count,
    p.comment_count,
    p.created_at
FROM Posts p
INNER JOIN Users u ON p.user_id = u.user_id
ORDER BY p.created_at DESC;