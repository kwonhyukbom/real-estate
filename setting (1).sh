#!/bin/bash

# 변수 설정
DB_ROOT_PASSWORD="2330"
DB_NAME="file_upload_db"
DB_USER="file_user"
DB_PASSWORD="2330"
UPLOAD_DIR="/var/www/html/uploads"

# 시스템 업데이트 및 필수 패키지 설치
sudo apt update
sudo apt upgrade -y
sudo apt install -y apache2 php libapache2-mod-php php-mysql mysql-server

# MySQL 설치 및 설정
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${DB_ROOT_PASSWORD}'; FLUSH PRIVILEGES;"
sudo mysql -u root -p${DB_ROOT_PASSWORD} -e "CREATE DATABASE ${DB_NAME};"
sudo mysql -u root -p${DB_ROOT_PASSWORD} -e "CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';"
sudo mysql -u root -p${DB_ROOT_PASSWORD} -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost'; FLUSH PRIVILEGES;"
sudo mysql -u root -p${DB_ROOT_PASSWORD} -e "USE ${DB_NAME}; CREATE TABLE files (id INT AUTO_INCREMENT PRIMARY KEY, filename VARCHAR(255) NOT NULL, filepath VARCHAR(255) NOT NULL, upload_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP);"

# Apache 설정 파일 수정
sudo a2enmod rewrite
sudo bash -c 'cat <<EOF > /etc/apache2/sites-available/000-default.conf
<VirtualHost *:80>
    DocumentRoot /var/www/html
    <Directory /var/www/html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF'

# 업로드 디렉토리 생성 및 권한 설정
sudo mkdir -p ${UPLOAD_DIR}
sudo chown www-data:www-data ${UPLOAD_DIR}
sudo chmod 755 ${UPLOAD_DIR}

# PHP 파일 생성
sudo bash -c 'cat <<EOF > /var/www/html/config.php
<?php
\$host = "localhost";
\$db = "'${DB_NAME}'";
\$user = "'${DB_USER}'";
\$pass = "'${DB_PASSWORD}'";

\$mysqli = new mysqli(\$host, \$user, \$pass, \$db);

if (\$mysqli->connect_error) {
    die("Connect Error (" . \$mysqli->connect_errno . ") " . \$mysqli->connect_error);
}
?>
EOF'

sudo bash -c 'cat <<EOF > /var/www/html/index.php
<!doctype html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>File Upload</title>
</head>
<body>
    <h1>File Upload</h1>
    <form action="upload.php" method="post" enctype="multipart/form-data">
        <input type="file" name="file">
        <input type="submit" value="Upload">
    </form>
    <h2>Uploaded Files</h2>
    <ul>
        <?php
        include "config.php";
        \$result = \$mysqli->query("SELECT * FROM files");
        while (\$row = \$result->fetch_assoc()) {
            echo "<li><a href='download.php?file=" . \$row["filename"] . "'>" . \$row["filename"] . "</a></li>";
        }
        ?>
    </ul>
</body>
</html>
EOF'

sudo bash -c 'cat <<EOF > /var/www/html/upload.php
<?php
include "config.php";

if (isset(\$_FILES["file"])) {
    \$errors = [];
    \$path = "'${UPLOAD_DIR}'/";

    \$file_name = \$_FILES["file"]["name"];
    \$file_tmp = \$_FILES["file"]["tmp_name"];
    \$file_size = \$_FILES["file"]["size"];
    \$file_ext = strtolower(pathinfo(\$file_name, PATHINFO_EXTENSION));
    \$file_mime = mime_content_type(\$file_tmp);

    if (\$file_size > 2097152) {
        die("File size exceeds limit.");
    }

    \$new_file_name = uniqid() . "." . \$file_ext;
    \$file_path = \$path . \$new_file_name;

    if (empty(\$errors)) {
        move_uploaded_file(\$file_tmp, \$file_path);

        \$stmt = \$mysqli->prepare("INSERT INTO files (filename, filepath) VALUES (?, ?)");
        \$stmt->bind_param("ss", \$new_file_name, \$file_path);
        \$stmt->execute();
        \$stmt->close();
    }

    if (\$errors) {
        print_r(\$errors);
    }
}

header("Location: index.php");
?>
EOF'

sudo bash -c 'cat <<EOF > /var/www/html/download.php
<?php
include "config.php";

if (isset(\$_GET["file"])) {
    \$stmt = \$mysqli->prepare("SELECT filepath FROM files WHERE filename = ?");
    \$stmt->bind_param("s", \$_GET["file"]);
    \$stmt->execute();
    \$stmt->bind_result(\$file_path);
    \$stmt->fetch();
    \$stmt->close();

    if (file_exists(\$file_path)) {
        header("Content-Description: File Transfer");
        header("Content-Type: application/octet-stream");
        header("Content-Disposition: attachment; filename=\"" . basename(\$file_path) . "\"");
        header("Expires: 0");
        header("Cache-Control: must-revalidate");
        header("Pragma: public");
        header("Content-Length: " . filesize(\$file_path));
        readfile(\$file_path);
        exit;
    }
}
?>
EOF'

# Apache 재시작 및 index.html 삭제
sudo rm /var/www/html/index.html

sudo systemctl restart apache2

echo "Setup completed. You can access the web application at http://your_server_ip/"
