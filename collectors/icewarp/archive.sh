#!/bin/bash

# Checklist items resolved here (verified against Mail > Archive screenshot):
#   "Archive Active"                       -> C_System_Tools_AutoArchive_Enable
#   "Archive to directory"                 -> C_System_Tools_AutoArchive_Path (already read in storage_paths.sh as icewarp.path.archive)
#   "Integrate Archive with IMAP Folder"   -> C_System_Tools_AutoArchive_IMAPArchive
#   "Do Not Archive Spam"                  -> C_System_Tools_AutoArchive_DoNotSpam
#   plus retention/backup settings shown in the same screen

collector_run() {

    collector_set "archive.active" "$(iw_get "C_System_Tools_AutoArchive_Enable" "" "" "")"
    collector_set "archive.trailer_path" "$(iw_get "C_System_Tools_AutoArchive_TrailerPath" "" "" "")"
    collector_set "archive.integrate_with_imap" "$(iw_get "C_System_Tools_AutoArchive_IMAPArchive" "" "" "")"
    collector_set "archive.imap_folder_name" "$(iw_get "C_System_Tools_AutoArchive_IMAPArchiveName" "" "" "")"
    collector_set "archive.do_not_archive_spam" "$(iw_get "C_System_Tools_AutoArchive_DoNotSpam" "" "" "")"
    collector_set "archive.do_not_archive_rss" "$(iw_get "C_System_Tools_AutoArchive_RSS" "" "" "")"
    collector_set "archive.delete_older_than_days" "$(iw_get "C_System_Tools_AutoArchive_DeleteOlder" "" "" "")"
    collector_set "archive.backup.active" "$(iw_get "C_System_Tools_AutoArchive_Backup_Active" "" "" "")"
    collector_set "archive.backup.delete_older_than_days" "$(iw_get "C_System_Tools_AutoArchive_Backup_DeleteOlder" "" "" "")"
    collector_set "archive.backup.file" "$(iw_get "C_System_Tools_AutoArchive_Backup_File" "" "" "")"

}
