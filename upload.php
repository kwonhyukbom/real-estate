<?php

// Maximum upload file size (in bytes)
$maxFileSize = 1048576; // 1MB

// Allowed file extensions
$allowedExtensions = array("jpg", "jpeg", "png", "gif", "txt", "php");

// Uploaded file information
$fileInfo = $_FILES["myfile"];

// File error handling
if ($fileInfo["error"] != UPLOAD_ERR_OK) {
    switch ($fileInfo["error"]) {
        case UPLOAD_ERR_INI_SIZE:
            echo "The file size exceeds the limit.";
            break;
        case UPLOAD_ERR_FORM_SIZE:
            echo "The file size allowed by the HTML form exceeds the limit.";
            break;
        case UPLOAD_ERR_PARTIAL_UPLOAD:
            echo "The file upload was not completed.";
            break;
        case UPLOAD_ERR_NO_FILE:
            echo "No file selected.";
            break;
        default:
            echo "An unknown error occurred.";
    }
    exit;
}

// Check file extension
$fileExtension = pathinfo($fileInfo["name"], PATHINFO_EXTENSION);
if (!in_array($fileExtension, $allowedExtensions)) {
    echo "Invalid file format.";
    exit;
}

// Temporary file path
$tempFilePath = $fileInfo["tmp_name"];

// Target file path
$targetFilePath = "uploads/" . $fileInfo["name"];

// Move the file
if (move_uploaded_file($tempFilePath, $targetFilePath)) {
    echo "File upload successfully completed.";
} else {
    echo "Failed to upload file.";
}

?>