import 'package:flutter/material.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [
    Locale('en'),
    Locale('vi'),
  ];

  static const _localizedValues = <String, Map<String, String>>{
    'en': {
      'app_title': 'WardMail',

      // Common
      'common_ok': 'OK',
      'common_cancel': 'Cancel',
      'common_close': 'Close',
      'common_logout': 'Log out',

      // Auth / login
      'login_title': 'Sign in',
      'login_subtitle': 'WardMail protects Gmail from phishing emails',
      'login_with': 'Sign in with',
      'login_email': 'Sign in with Email',
      'login_no_account': "Don't have an account? ",
      'login_register_email': 'Sign up with Email',

      'email_login_title': 'Sign in with email and password',
      'email_field': 'Email',
      'password_field': 'Password',
      'login_button': 'Sign in',
      'forgot_password': 'Forgot password?',
      'no_account': "Don't have an account? ",
      'register_now': 'Sign up now',

      'register_title': 'Create a new account to continue',
      'name_field': 'Full name',
      'confirm_password_field': 'Confirm password',
      'register_button': 'Sign up',
      'has_account': 'Already have an account? ',
      'login_here': 'Sign in',

      // Biometric
      'biometric_title': 'Security verification',
      'biometric_subtitle': 'Use fingerprint or PIN to unlock the app',
      'biometric_button': 'Authenticate',

      // Home / navigation
      'home_search_hint': 'Search in emails',
      'home_notifications_tooltip': 'Notifications',
      'drawer_section_analysis': 'Email analysis',
      'drawer_check_phishing': 'Phishing check',
      'drawer_statistics': 'Statistics',
      'drawer_reports': 'Detailed reports',
      'drawer_settings_section': 'Settings',
      'drawer_security': 'Security',
      'drawer_about': 'About',
      'drawer_help': 'Help',

      // Settings bottom sheet
      'settings_title': 'WardMail settings',
      'settings_description':
          'Customize security and how WardMail analyzes emails for you.',
      'settings_biometric_title': 'Fingerprint authentication',
      'settings_biometric_on': 'Fingerprint security is enabled',
      'settings_biometric_off': 'Fingerprint security is disabled',
      'settings_theme_title': 'Light/Dark theme',
      'settings_theme_subtitle': 'Choose the appearance that suits you',
      'settings_theme_system': 'Follow system',
      'settings_theme_light': 'Light mode',
      'settings_theme_dark': 'Dark mode',
      'settings_auto_analysis_title': 'Auto-analyze new emails',
      'settings_auto_analysis_on':
          'New emails will be analyzed by AI in the background and saved to statistics',
      'settings_auto_analysis_off':
          'Only receive new email notifications, no automatic analysis',
      'settings_logout': 'Log out',

      // Language
      'settings_language_title': 'Language',
      'settings_language_vi': 'Vietnamese',
      'settings_language_en': 'English',

      // Notifications screen
      'notifications_title': 'Notifications',
      'notifications_empty_title': 'No notifications yet',
      'notifications_empty_body':
          'Security and email notifications\nwill appear here',

      // Statistics / Reports
      'statistics_title': 'Statistics',
      'statistics_refresh': 'Refresh',
      'statistics_clear_history_menu': 'Clear history',
      'statistics_clear_history_title': 'Confirm',
      'statistics_clear_history_message':
          'Are you sure you want to clear all history?',
      'statistics_empty_title': 'No data yet',
      'statistics_empty_subtitle':
          'Scan some emails to see statistics',
      'statistics_overview_title': 'Overview',
      'statistics_total_label': 'Total',
      'statistics_distribution_title': 'Result distribution',
      'statistics_recent_scans_title': 'Recent scans',
      'reports_title': 'Detailed reports',

      // Statistics / Reports - details
      'reports_tab_trends': 'Trends',
      'reports_tab_details': 'Details',
      'reports_tab_analysis': 'Analysis',
      'reports_export_pdf': 'Export PDF',
      'reports_export_csv': 'Export CSV',
      'reports_empty_title': 'No reports yet',
      'reports_empty_subtitle': 'Scan some emails to generate reports',
      'reports_range_7_days': '7 days',
      'reports_range_30_days': '30 days',
      'reports_range_all': 'All',
      'reports_timeline_all_time': 'All-time trend',
      'reports_timeline_30_days': 'Last 30 days trend',
      'reports_timeline_7_days': 'Last 7 days trend',
      'reports_no_data': 'No data',
      'reports_legend_phishing': 'Dangerous',
      'reports_legend_suspicious': 'Suspicious',
      'reports_legend_safe': 'Safe',
      'reports_daily_analysis_title': 'Daily analysis',
      'reports_status_phishing': 'Dangerous',
      'reports_status_suspicious': 'Suspicious',
      'reports_status_safe': 'Safe',
      'reports_from_label': 'From: {from}',
      'reports_common_threats_title': 'Common threats',
      'reports_common_threats_empty': 'No threats have been detected',
      'reports_security_recommendations_title': 'Security recommendations',
      'reports_analysis_dangerous_desc':
          'Detected clear phishing indicators',
      'reports_analysis_suspicious_desc':
          'Needs to be reviewed more carefully',
      'reports_recommendation_1_title': 'Do not click on strange links',
      'reports_recommendation_1_desc':
          'Always check the URL before clicking any link in an email.',
      'reports_recommendation_2_title': 'Verify the sender',
      'reports_recommendation_2_desc':
          'Check whether the sender email address matches the official domain.',
      'reports_recommendation_3_title': 'Beware of urgent emails',
      'reports_recommendation_3_desc':
          'Emails that ask you to act quickly are often a sign of phishing.',
      'reports_recommendation_4_title': 'Enable two-factor authentication',
      'reports_recommendation_4_desc':
          'Add an extra layer of security for important accounts.',

      // Email detail / analysis
      'email_detail_analyzing': 'Analyzing...',
      'email_detail_analyze': 'Analyze email',
      'email_detail_reanalyze': 'Analyze again',
      'email_detail_analysis_done': 'Analysis completed!',
      'email_detail_analysis_error': 'Analysis failed: {error}',
      'email_detail_status_phishing': 'DANGEROUS',
      'email_detail_status_suspicious': 'SUSPICIOUS',
      'email_detail_status_safe': 'SAFE',
      'email_detail_status_phishing_desc':
          'This email shows signs of fraud. Do not click links or download attachments.',
      'email_detail_status_suspicious_desc':
          'This email has some suspicious signs. Be careful when interacting.',
      'email_detail_status_safe_desc':
          'This email has been checked and appears safe.',
      'email_detail_detected_threats': 'Detected threats:',
      'email_detail_analyzed_at': 'Analyzed at: {time}',
      'email_detail_info_title': 'Email information',
      'email_detail_info_subject': 'Subject:',
      'email_detail_info_date': 'Date:',
      'email_detail_info_content': 'Content:',
      'email_detail_threat_detail_title': 'Threat details',
      'email_detail_threat_detail_close': 'Close',
      'email_detail_confidence_phishing': 'Danger level: {percent}%',
      'email_detail_confidence_suspicious': 'Suspicion level: {percent}%',
      'email_detail_confidence_safe': 'Safety level: {percent}%',
      'email_detail_menu_reply': 'Reply',
      'email_detail_menu_forward': 'Forward',
      'email_detail_menu_compose': 'Compose new email',
      'email_detail_ask_ai_tooltip': 'Ask AI about this email',

      // Gemini analysis section
      'gemini_analysis_title': 'Analyzed by Gemini AI',
      'gemini_analysis_reasons_title': 'Reasons:',
      'gemini_analysis_recommendations_title': 'Recommendations:',
      'gemini_analysis_details_title': 'Detailed analysis',

      // Notifications (foreground)
      'notif_phishing_title': '🚨 Phishing email detected!',
      'notif_phishing_body': 'Email from {from} looks like a scam',
      'notif_suspicious_title': '⚠️ Suspicious email',
      'notif_suspicious_body': 'Email from {from} should be checked carefully',
      'notif_safe_title': '✅ Safe email',
      'notif_safe_body': 'Email from {from} has been checked and is safe',

      // Home screen / settings extras
      'auto_analysis_enabled_snackbar': 'Auto-analyze new emails has been enabled',
      'auto_analysis_disabled_snackbar':
          'Auto-analyze new emails has been disabled',
      'biometric_auth_failed': 'Authentication failed',
      'biometric_enabled_snackbar': 'Fingerprint authentication enabled',
      'biometric_disabled_snackbar': 'Fingerprint authentication disabled',
      'logout_confirm_title': 'Log out',
      'logout_confirm_message': 'Are you sure you want to log out?',

      // Intro sheet
      'intro_description':
          'WardMail helps you detect and block scam and phishing emails directly in your Gmail inbox.',
      'intro_what_can_do_title': 'What can WardMail do?',
      'intro_feature_scan_title': 'Scan email content with AI',
      'intro_feature_scan_desc':
          'Analyze subject, content and links to detect signs of fraud.',
      'intro_feature_notify_title': 'Instant notifications',
      'intro_feature_notify_desc':
          'Alert you when dangerous or phishing emails are detected.',
      'intro_feature_stats_title': 'Statistics & detailed reports',
      'intro_feature_stats_desc':
          'Track scan history and the ratio of safe, suspicious and dangerous emails.',
      'intro_tip_auto_analysis':
          'Tip: Turn on "Auto-analyze new emails" in Settings so WardMail can protect you even when the app is closed.',

      // Help sheet
      'help_quick_title': 'Quick help',
      'help_section1_title': '1. How do I get started?',
      'help_section1_content':
          '• Sign in with Google or Email.\n'
          '• Connect Gmail and allow WardMail to read emails for analysis.\n'
          '• Open Settings and enable auto-analysis for new emails.',
      'help_section2_title': '2. What do the warning colors mean?',
      'help_section2_content':
          '• Green: Safe email.\n'
          '• Yellow: Suspicious email, you should double-check.\n'
          '• Red: Dangerous email, avoid clicking links or downloading attachments.',
      'help_section3_title': '3. What should I do with suspicious emails?',
      'help_section3_content':
          '• Do not reply, do not provide passwords or OTP codes.\n'
          '• Avoid clicking links or downloading unknown files.\n'
          '• Report the email as spam/phishing in Gmail so Google can block it better.',
      'help_section4_title': '4. Does WardMail read my private content?',
      'help_section4_content':
          'WardMail only analyzes email content to detect signs of fraud. '
          'Data is processed securely and used only to protect you.',

      // Recaptcha
      'recaptcha_verified': 'reCAPTCHA verified',
      'recaptcha_not_robot': "I'm not a robot",
      'recaptcha_title': 'Verify reCAPTCHA',

      // Auth / validation messages
      'recaptcha_not_verified_snackbar':
          'Could not verify reCAPTCHA, please try again',
      'validation_enter_email': 'Please enter your email',
      'validation_email_invalid': 'Invalid email address',
      'validation_enter_password': 'Please enter your password',
      'validation_enter_name': 'Please enter your full name',
      'validation_enter_password_confirm': 'Please confirm your password',
      'validation_password_mismatch': 'Passwords do not match',
      'validation_password_min_length':
          'Password must be at least 8 characters',
      'validation_password_requirements':
          'Password must contain uppercase, lowercase, numbers and special characters',
      'password_strength_weak': 'Weak password',
      'password_strength_medium': 'Medium strength password',
      'password_strength_strong': 'Strong password',
      'forgot_password_enter_email':
          'Please enter your email to reset the password',
      'forgot_password_email_sent':
          'Password reset email has been sent!',
      // Email verification
      'email_verification_title': 'Verify email',
      'email_verification_sent_to':
          'We have sent a verification email to:',
      'email_verification_check_email_title': 'Please check your email',
      'email_verification_check_email_desc':
          'Click the link in the email to verify your account. Check the spam folder if you do not see it.',
      'email_verification_waiting': 'Waiting for verification...',
      'email_verification_not_received': "Didn't receive the email?",
      'email_verification_resend': 'Resend email',
      'email_verification_resend_after_seconds':
          'Resend after {seconds} seconds',
      'error_generic': 'An error occurred',
      'error_user_not_found': 'Account not found',
      'error_wrong_password': 'Incorrect password',
      'error_invalid_email': 'Invalid email address',
      'error_user_disabled': 'Account has been disabled',
      'error_email_already_in_use': 'This email is already registered',
      'error_weak_password': 'Password is too weak',
      'error_with_message': 'Error: {message}',

      // Login screen extras
      'login_cancelled': 'Sign in was cancelled',
      'login_error_with_message': 'Sign in error: {message}',
      'login_or': 'or',

      // Theme toggle
      'theme_toggle_to_light': 'Switch to light mode',
      'theme_toggle_to_dark': 'Switch to dark mode',

      // User
      'user_default_display_name': 'User',

      // Gmail AI chat & suggestions
      'gmail_ai_chat_title': 'Gmail AI chat',
      'gmail_ai_chat_intro':
          'This chatbot helps you ask general questions about Gmail: usage, inbox management, account security and how to recognize spam/phishing emails. To analyze a specific email, use AI in the email detail screen.',
      'gmail_ai_chat_input_hint':
          'Ask AI about Gmail usage, security, spam/phishing...',
      'gmail_ai_chat_error': 'Could not connect to AI: {error}',
      'gmail_ai_suggestions_title': 'Suggestions for asking AI about Gmail',
      'gmail_ai_suggestion_1':
          'How can I recognize phishing emails in Gmail?',
      'gmail_ai_suggestion_2':
          'What should I do when I receive a suspicious email?',
      'gmail_ai_suggestion_3':
          'Guide to protect my Gmail account from being hacked.',
      'gmail_ai_suggestion_4':
          'Explain how to report spam/phishing in Gmail.',

      // Email AI chat (per email)
      'email_ai_suggestion_1': 'Is this email trustworthy?',
      'email_ai_suggestion_2': 'Does this email show signs of phishing?',
      'email_ai_suggestion_3': 'Summarize the content of this email for me.',
      'email_ai_suggestion_4': 'What should I do with this email?',

      // Compose email
      'compose_email_title': 'Compose email',
      'compose_email_to_label': 'To',
      'compose_email_to_hint': 'e.g. user@gmail.com',
      'compose_email_to_required': 'Please enter recipient email',
      'compose_email_subject_label': 'Subject',
      'compose_email_attach_button': 'Attach files',
      'compose_email_attachments_count': '{count} file(s) selected',
      'compose_email_body_label': 'Content',
      'compose_email_sent': 'Email sent successfully',
      'compose_email_send_error': 'Failed to send email: {error}',
      'compose_email_preview_not_supported':
          'Cannot preview this file. You can still send it as an attachment.',

      // Email list
      'email_list_tab_inbox': 'Inbox',
      'email_list_tab_sent': 'Sent',
      'email_list_tab_trash': 'Trash',
      'email_list_setup_title': 'Connect Gmail',
      'email_list_setup_description':
          'To read emails from Gmail, you need to configure an App Password.',
      'email_list_setup_button': 'Set up now',
      'email_list_error_title': 'Failed to load emails',
      'email_list_error_retry': 'Try again',
      'email_list_error_reconfigure': 'Reconfigure',
      'email_list_empty_title': 'No emails',
      'email_list_delete_confirm_title': 'Move to Trash?',
      'email_list_delete_confirm_message':
          'The email will be moved to the Trash in Gmail.',
      'email_list_snackbar_moved_to_trash':
          'Email has been moved to Trash',
      'email_list_snackbar_delete_error':
          'Failed to delete email: {error}',
      'email_list_snackbar_no_selected_restore':
          'No emails selected to restore',
      'email_list_snackbar_restore_google_only':
          'Restoring from Trash is only supported for Google accounts',
      'email_list_snackbar_restored':
          'Selected emails have been restored to Inbox',
      'email_list_snackbar_no_selected_delete':
          'No emails selected to delete',
      'email_list_snackbar_delete_google_only':
          'Bulk delete is only supported for Google accounts',
      'email_list_snackbar_deleted':
          'Selected emails have been moved to Trash',
      'email_list_preview_open_detail': 'Open details',
      'email_list_restore_selected': 'Restore selected emails',
      'email_list_exit_selection': 'Exit selection mode',
      'email_list_delete_selected': 'Delete selected emails',
      'email_list_trash_select': 'Select emails in Trash',
      'email_list_inbox_select': 'Select emails in Inbox',
      'email_list_error_cannot_open_email': 'Cannot open this email',
      'email_list_date_yesterday': 'Yesterday',
      'email_list_date_days_ago': '{days} days',

      // Notifications screen extras
      'notifications_unread_count': '{count} unread',
      'notifications_delete_title': 'Delete notification',
      'notifications_delete_message':
          'Are you sure you want to delete this notification?',
      'notifications_delete_all_title': 'Delete all',
      'notifications_delete_all_message':
          'Are you sure you want to delete all notifications?',
      'notifications_action_cancel': 'Cancel',
      'notifications_action_delete': 'Delete',
      'notifications_action_mark_read': 'Mark as read',
      'notifications_action_clear_all': 'Delete all',
      'notifications_relative_just_now': 'Just now',
      'notifications_relative_minutes_ago': '{minutes} minutes ago',
      'notifications_relative_hours_ago': '{hours} hours ago',
      'notifications_relative_days_ago': '{days} days ago',
      'notifications_error_open_email': 'Cannot open email: {error}',

      // Monitoring
      'monitoring_start_error': 'Failed to start monitoring: {error}',
    },
    'vi': {
      'app_title': 'WardMail',

      // Common
      'common_ok': 'OK',
      'common_cancel': 'Hủy',
      'common_close': 'Đóng',
      'common_logout': 'Đăng xuất',

      // Auth / login
      'login_title': 'Đăng nhập',
      'login_subtitle':
          'WardMail bảo vệ Gmail khỏi email lừa đảo và phishing',
      'login_with': 'Đăng nhập bằng',
      'login_email': 'Đăng nhập bằng Email',
      'login_no_account': 'Bạn chưa có tài khoản? ',
      'login_register_email': 'Đăng ký bằng Email',

      'email_login_title': 'Đăng nhập bằng email và mật khẩu',
      'email_field': 'Email',
      'password_field': 'Mật khẩu',
      'login_button': 'Đăng nhập',
      'forgot_password': 'Quên mật khẩu?',
      'no_account': 'Chưa có tài khoản? ',
      'register_now': 'Đăng ký ngay',

      'register_title': 'Tạo tài khoản mới để tiếp tục',
      'name_field': 'Họ và tên',
      'confirm_password_field': 'Xác nhận mật khẩu',
      'register_button': 'Đăng ký',
      'has_account': 'Đã có tài khoản? ',
      'login_here': 'Đăng nhập',

      // Biometric
      'biometric_title': 'Xác thực bảo mật',
      'biometric_subtitle':
          'Sử dụng vân tay hoặc PIN\nđể mở khóa ứng dụng',
      'biometric_button': 'Xác thực',

      // Home / navigation
      'home_search_hint': 'Tìm kiếm trong email',
      'home_notifications_tooltip': 'Thông báo',
      'drawer_section_analysis': 'Phân tích Email',
      'drawer_check_phishing': 'Kiểm tra Phishing',
      'drawer_statistics': 'Thống kê',
      'drawer_reports': 'Báo cáo chi tiết',
      'drawer_settings_section': 'Cài đặt',
      'drawer_security': 'Bảo mật',
      'drawer_about': 'Giới thiệu',
      'drawer_help': 'Trợ giúp',

      // Settings bottom sheet
      'settings_title': 'Cài đặt WardMail',
      'settings_description':
          'Tuỳ chỉnh bảo mật và cách WardMail phân tích email cho bạn.',
      'settings_biometric_title': 'Xác thực vân tay',
      'settings_biometric_on': 'Bật bảo mật vân tay',
      'settings_biometric_off': 'Tắt bảo mật vân tay',
      'settings_theme_title': 'Giao diện sáng/tối',
      'settings_theme_subtitle': 'Chọn chế độ hiển thị phù hợp với bạn',
      'settings_theme_system': 'Theo hệ thống',
      'settings_theme_light': 'Nền sáng',
      'settings_theme_dark': 'Nền tối',
      'settings_auto_analysis_title': 'Tự động phân tích email mới',
      'settings_auto_analysis_on':
          'Email mới sẽ được AI phân tích ngầm và lưu thống kê',
      'settings_auto_analysis_off':
          'Chỉ nhận thông báo email mới, không phân tích tự động',
      'settings_logout': 'Đăng xuất',

      // Language
      'settings_language_title': 'Ngôn ngữ',
      'settings_language_vi': 'Tiếng Việt',
      'settings_language_en': 'Tiếng Anh',

      // Notifications screen
      'notifications_title': 'Thông báo',
      'notifications_empty_title': 'Chưa có thông báo',
      'notifications_empty_body':
          'Các thông báo về email và bảo mật\nsẽ hiển thị ở đây',

      // Statistics / Reports
      'statistics_title': 'Thống kê',
      'statistics_refresh': 'Làm mới',
      'statistics_clear_history_menu': 'Xóa lịch sử',
      'statistics_clear_history_title': 'Xác nhận',
      'statistics_clear_history_message':
          'Bạn có chắc chắn muốn xóa toàn bộ lịch sử?',
      'statistics_empty_title': 'Chưa có dữ liệu',
      'statistics_empty_subtitle': 'Kiểm tra email để xem thống kê',
      'statistics_overview_title': 'Tổng quan',
      'statistics_total_label': 'Tổng số',
      'statistics_distribution_title': 'Phân bổ kết quả',
      'statistics_recent_scans_title': 'Kiểm tra gần đây',
      'reports_title': 'Báo cáo chi tiết',

      // Statistics / Reports - details
      'reports_tab_trends': 'Xu hướng',
      'reports_tab_details': 'Chi tiết',
      'reports_tab_analysis': 'Phân tích',
      'reports_export_pdf': 'Xuất PDF',
      'reports_export_csv': 'Xuất CSV',
      'reports_empty_title': 'Chưa có báo cáo',
      'reports_empty_subtitle': 'Kiểm tra email để tạo báo cáo',
      'reports_range_7_days': '7 ngày',
      'reports_range_30_days': '30 ngày',
      'reports_range_all': 'Tất cả',
      'reports_timeline_all_time': 'Xu hướng toàn bộ thời gian',
      'reports_timeline_30_days': 'Xu hướng 30 ngày qua',
      'reports_timeline_7_days': 'Xu hướng 7 ngày qua',
      'reports_no_data': 'Không có dữ liệu',
      'reports_legend_phishing': 'Nguy hiểm',
      'reports_legend_suspicious': 'Nghi ngờ',
      'reports_legend_safe': 'An toàn',
      'reports_daily_analysis_title': 'Phân tích theo ngày',
      'reports_status_phishing': 'Nguy hiểm',
      'reports_status_suspicious': 'Nghi ngờ',
      'reports_status_safe': 'An toàn',
      'reports_from_label': 'Từ: {from}',
      'reports_common_threats_title': 'Mối đe dọa phổ biến',
      'reports_common_threats_empty': 'Không có mối đe dọa nào được phát hiện',
      'reports_security_recommendations_title': 'Khuyến nghị bảo mật',
      'reports_analysis_dangerous_desc':
          'Phát hiện dấu hiệu phishing rõ ràng',
      'reports_analysis_suspicious_desc':
          'Cần xem xét kỹ hơn',
      'reports_recommendation_1_title': 'Không nhấp vào link lạ',
      'reports_recommendation_1_desc':
          'Luôn kiểm tra URL trước khi nhấp vào bất kỳ liên kết nào trong email',
      'reports_recommendation_2_title': 'Xác minh người gửi',
      'reports_recommendation_2_desc':
          'Kiểm tra địa chỉ email người gửi có khớp với domain chính thức không',
      'reports_recommendation_3_title': 'Cảnh giác với email khẩn cấp',
      'reports_recommendation_3_desc':
          'Email yêu cầu hành động gấp thường là dấu hiệu của phishing',
      'reports_recommendation_4_title': 'Bật xác thực 2 yếu tố',
      'reports_recommendation_4_desc':
          'Thêm lớp bảo mật cho tài khoản quan trọng',

      // Email detail / analysis
      'email_detail_analyzing': 'Đang phân tích...',
      'email_detail_analyze': 'Phân tích Email',
      'email_detail_reanalyze': 'Phân tích lại Email',
      'email_detail_analysis_done': 'Phân tích hoàn tất!',
      'email_detail_analysis_error': 'Lỗi phân tích: {error}',
      'email_detail_status_phishing': 'NGUY HIỂM',
      'email_detail_status_suspicious': 'NGHI NGỜ',
      'email_detail_status_safe': 'AN TOÀN',
      'email_detail_status_phishing_desc':
          'Email này có dấu hiệu lừa đảo. Không nên mở link hoặc tải file đính kèm.',
      'email_detail_status_suspicious_desc':
          'Email này có một số dấu hiệu đáng ngờ. Hãy cẩn thận khi tương tác.',
      'email_detail_status_safe_desc':
          'Email này đã được kiểm tra và có vẻ an toàn.',
      'email_detail_detected_threats': 'Mối đe dọa phát hiện:',
      'email_detail_analyzed_at': 'Phân tích lúc: {time}',
      'email_detail_info_title': 'Thông tin Email',
      'email_detail_info_subject': 'Tiêu đề:',
      'email_detail_info_date': 'Ngày:',
      'email_detail_info_content': 'Nội dung:',
      'email_detail_threat_detail_title': 'Chi tiết mối đe dọa',
      'email_detail_threat_detail_close': 'Đóng',
      'email_detail_confidence_phishing': 'Độ nguy hiểm: {percent}%',
      'email_detail_confidence_suspicious': 'Mức độ nghi ngờ: {percent}%',
      'email_detail_confidence_safe': 'Độ an toàn: {percent}%',
      'email_detail_menu_reply': 'Trả lời',
      'email_detail_menu_forward': 'Chuyển tiếp',
      'email_detail_menu_compose': 'Soạn email mới',
      'email_detail_ask_ai_tooltip': 'Hỏi AI về email',

      // Gemini analysis section
      'gemini_analysis_title': 'Phân tích bởi Gemini AI',
      'gemini_analysis_reasons_title': 'Lý do đánh giá:',
      'gemini_analysis_recommendations_title': 'Khuyến nghị:',
      'gemini_analysis_details_title': 'Phân tích chi tiết',

      // Notifications (foreground)
      'notif_phishing_title': '🚨 Phát hiện email phishing!',
      'notif_phishing_body': 'Email từ {from} có dấu hiệu lừa đảo',
      'notif_suspicious_title': '⚠️ Email nghi ngờ',
      'notif_suspicious_body':
          'Email từ {from} cần xem xét kỹ hơn',
      'notif_safe_title': '✅ Email an toàn',
      'notif_safe_body':
          'Email từ {from} đã được kiểm tra và an toàn',

      // Home screen / settings extras
      'auto_analysis_enabled_snackbar':
          'Đã bật tự động phân tích email mới',
      'auto_analysis_disabled_snackbar':
          'Đã tắt tự động phân tích email mới',
      'biometric_auth_failed': 'Xác thực thất bại',
      'biometric_enabled_snackbar': 'Đã bật xác thực vân tay',
      'biometric_disabled_snackbar': 'Đã tắt xác thực vân tay',
      'logout_confirm_title': 'Đăng xuất',
      'logout_confirm_message': 'Bạn có chắc chắn muốn đăng xuất?',

      // Intro sheet
      'intro_description':
          'WardMail giúp bạn phát hiện và chặn email lừa đảo, phishing '
          'ngay trong hộp thư Gmail.',
      'intro_what_can_do_title': 'WardMail làm được gì?',
      'intro_feature_scan_title': 'Quét nội dung email bằng AI',
      'intro_feature_scan_desc':
          'Phân tích tiêu đề, nội dung, liên kết để phát hiện dấu hiệu lừa đảo.',
      'intro_feature_notify_title': 'Thông báo tức thì',
      'intro_feature_notify_desc':
          'Cảnh báo khi phát hiện email nguy hiểm hoặc có dấu hiệu phishing.',
      'intro_feature_stats_title': 'Thống kê & báo cáo chi tiết',
      'intro_feature_stats_desc':
          'Theo dõi lịch sử quét, tỷ lệ email an toàn, nghi ngờ và nguy hiểm.',
      'intro_tip_auto_analysis':
          'Mẹo nhỏ: Hãy bật "Tự động phân tích email mới" trong phần Cài đặt '
          'để WardMail bảo vệ bạn ngay cả khi không mở ứng dụng.',

      // Help sheet
      'help_quick_title': 'Trợ giúp nhanh',
      'help_section1_title': '1. Làm sao để bắt đầu?',
      'help_section1_content':
          '• Đăng nhập bằng Google hoặc Email.\n'
          '• Kết nối Gmail và cho phép WardMail đọc email để phân tích.\n'
          '• Vào phần Cài đặt để bật tự động phân tích email mới.',
      'help_section2_title': '2. Màu sắc cảnh báo nghĩa là gì?',
      'help_section2_content':
          '• Xanh lá: Email an toàn.\n'
          '• Vàng: Email có dấu hiệu nghi ngờ, nên kiểm tra kỹ.\n'
          '• Đỏ: Email nguy hiểm, không nên nhấp vào link hoặc tải file đính kèm.',
      'help_section3_title': '3. Tôi nên làm gì khi gặp email đáng ngờ?',
      'help_section3_content':
          '• Không trả lời email, không cung cấp mật khẩu hoặc mã OTP.\n'
          '• Tránh nhấp vào liên kết hoặc tải xuống tệp lạ.\n'
          '• Báo cáo email như spam/phishing trong Gmail để Google chặn tốt hơn.',
      'help_section4_title': '4. WardMail có xem nội dung riêng tư của tôi không?',
      'help_section4_content':
          'WardMail chỉ phân tích nội dung email để phát hiện dấu hiệu lừa đảo. '
          'Dữ liệu được xử lý bảo mật và chỉ phục vụ cho mục đích bảo vệ bạn.',

      // Recaptcha
      'recaptcha_verified': 'Đã xác minh reCAPTCHA',
      'recaptcha_not_robot': 'Tôi không phải người máy',
      'recaptcha_title': 'Xác minh reCAPTCHA',

      // Auth / validation messages
      'recaptcha_not_verified_snackbar':
          'Không xác minh được reCAPTCHA, vui lòng thử lại',
      'validation_enter_email': 'Vui lòng nhập email',
      'validation_email_invalid': 'Email không hợp lệ',
      'validation_enter_password': 'Vui lòng nhập mật khẩu',
      'validation_enter_name': 'Vui lòng nhập họ tên',
      'validation_enter_password_confirm': 'Vui lòng xác nhận mật khẩu',
      'validation_password_mismatch': 'Mật khẩu không khớp',
      'validation_password_min_length':
          'Mật khẩu phải có ít nhất 8 ký tự',
      'validation_password_requirements':
          'Mật khẩu phải có chữ hoa, chữ thường, số và ký tự đặc biệt',
      'password_strength_weak': 'Mật khẩu yếu',
      'password_strength_medium': 'Mật khẩu trung bình',
      'password_strength_strong': 'Mật khẩu mạnh',
      'forgot_password_enter_email':
          'Vui lòng nhập email để đặt lại mật khẩu',
      'forgot_password_email_sent':
          'Email đặt lại mật khẩu đã được gửi!',
      // Email verification
      'email_verification_title': 'Xác thực Email',
      'email_verification_sent_to':
          'Chúng tôi đã gửi email xác thực đến:',
      'email_verification_check_email_title': 'Vui lòng kiểm tra email',
      'email_verification_check_email_desc':
          'Nhấp vào link trong email để xác thực tài khoản. Kiểm tra cả thư mục spam nếu không thấy.',
      'email_verification_waiting': 'Đang chờ xác thực...',
      'email_verification_not_received': 'Không nhận được email?',
      'email_verification_resend': 'Gửi lại email',
      'email_verification_resend_after_seconds':
          'Gửi lại sau {seconds} giây',
      'error_generic': 'Đã xảy ra lỗi',
      'error_user_not_found': 'Không tìm thấy tài khoản',
      'error_wrong_password': 'Mật khẩu không đúng',
      'error_invalid_email': 'Email không hợp lệ',
      'error_user_disabled': 'Tài khoản đã bị vô hiệu hóa',
      'error_email_already_in_use':
          'Email này đã được đăng ký',
      'error_weak_password': 'Mật khẩu quá yếu',
      'error_with_message': 'Lỗi: {message}',

      // Login screen extras
      'login_cancelled': 'Đăng nhập bị hủy',
      'login_error_with_message': 'Lỗi đăng nhập: {message}',
      'login_or': 'hoặc',

      // Theme toggle
      'theme_toggle_to_light': 'Chuyển sang chế độ sáng',
      'theme_toggle_to_dark': 'Chuyển sang chế độ tối',

      // User
      'user_default_display_name': 'Người dùng',

      // Gmail AI chat & suggestions
      'gmail_ai_chat_title': 'Chat AI Gmail',
      'gmail_ai_chat_intro':
          'Chatbot này dùng để hỏi chung về Gmail: cách sử dụng, quản lý hộp thư, bảo mật tài khoản, nhận diện spam/phishing nói chung... Nếu muốn phân tích một email cụ thể, hãy dùng AI trong màn chi tiết email.',
      'gmail_ai_chat_input_hint':
          'Hỏi AI về cách dùng Gmail, bảo mật, spam/phishing...',
      'gmail_ai_chat_error': 'Không thể kết nối tới AI: {error}',
      'gmail_ai_suggestions_title': 'Gợi ý hỏi AI về Gmail',
      'gmail_ai_suggestion_1': 'Làm sao nhận diện email lừa đảo trong Gmail?',
      'gmail_ai_suggestion_2': 'Khi nhận email đáng ngờ tôi nên làm gì?',
      'gmail_ai_suggestion_3': 'Hướng dẫn bảo vệ tài khoản Gmail khỏi bị hack.',
      'gmail_ai_suggestion_4': 'Giải thích cách báo cáo spam/phishing trong Gmail.',

      // Email AI chat (per email)
      'email_ai_suggestion_1': 'Email này có đáng tin không?',
      'email_ai_suggestion_2': 'Email này có dấu hiệu lừa đảo không?',
      'email_ai_suggestion_3': 'Tóm tắt nội dung email giúp tôi.',
      'email_ai_suggestion_4': 'Tôi nên làm gì với email này?',

      // Compose email
      'compose_email_title': 'Soạn email',
      'compose_email_to_label': 'Người nhận',
      'compose_email_to_hint': 'ví dụ: user@gmail.com',
      'compose_email_to_required': 'Vui lòng nhập email người nhận',
      'compose_email_subject_label': 'Chủ đề',
      'compose_email_attach_button': 'Đính kèm file',
      'compose_email_attachments_count': '{count} file đã chọn',
      'compose_email_body_label': 'Nội dung',
      'compose_email_sent': 'Đã gửi email',
      'compose_email_send_error': 'Lỗi gửi email: {error}',
      'compose_email_preview_not_supported':
          'Không thể hiển thị trước nội dung file này. Bạn vẫn có thể gửi kèm file.',

      // Email list
      'email_list_tab_inbox': 'Hộp thư đến',
      'email_list_tab_sent': 'Đã gửi',
      'email_list_tab_trash': 'Thùng rác',
      'email_list_setup_title': 'Kết nối Gmail',
      'email_list_setup_description':
          'Để đọc email từ Gmail, bạn cần cấu hình App Password',
      'email_list_setup_button': 'Cấu hình ngay',
      'email_list_error_title': 'Lỗi tải email',
      'email_list_error_retry': 'Thử lại',
      'email_list_error_reconfigure': 'Cấu hình lại',
      'email_list_empty_title': 'Không có email',
      'email_list_delete_confirm_title': 'Chuyển vào Thùng rác?',
      'email_list_delete_confirm_message':
          'Email sẽ được chuyển vào Thùng rác trong Gmail.',
      'email_list_snackbar_moved_to_trash':
          'Đã chuyển email vào Thùng rác',
      'email_list_snackbar_delete_error': 'Lỗi xóa email: {error}',
      'email_list_snackbar_no_selected_restore':
          'Chưa chọn email nào để khôi phục',
      'email_list_snackbar_restore_google_only':
          'Khôi phục Thùng rác hiện chỉ hỗ trợ tài khoản Google',
      'email_list_snackbar_restored':
          'Đã khôi phục email về Hộp thư đến',
      'email_list_snackbar_no_selected_delete':
          'Chưa chọn email nào để xóa',
      'email_list_snackbar_delete_google_only':
          'Xóa nhiều email chỉ hỗ trợ tài khoản Google',
      'email_list_snackbar_deleted':
          'Đã chuyển email vào Thùng rác',
      'email_list_preview_open_detail': 'Mở chi tiết',
      'email_list_restore_selected': 'Khôi phục email đã chọn',
      'email_list_exit_selection': 'Thoát chế độ chọn',
      'email_list_delete_selected': 'Xóa email đã chọn',
      'email_list_trash_select': 'Chọn email trong Thùng rác',
      'email_list_inbox_select': 'Chọn email trong Hộp thư đến',
      'email_list_error_cannot_open_email': 'Không thể mở email này',
      'email_list_date_yesterday': 'Hôm qua',
      'email_list_date_days_ago': '{days} ngày',

      // Notifications screen extras
      'notifications_unread_count': '{count} chưa đọc',
      'notifications_delete_title': 'Xóa thông báo',
      'notifications_delete_message':
          'Bạn có chắc chắn muốn xóa thông báo này?',
      'notifications_delete_all_title': 'Xóa tất cả',
      'notifications_delete_all_message':
          'Bạn có chắc chắn muốn xóa tất cả thông báo?',
      'notifications_action_cancel': 'Hủy',
      'notifications_action_delete': 'Xóa',
      'notifications_action_mark_read': 'Đánh dấu đã đọc',
      'notifications_action_clear_all': 'Xóa tất cả',
      'notifications_relative_just_now': 'Vừa xong',
      'notifications_relative_minutes_ago': '{minutes} phút trước',
      'notifications_relative_hours_ago': '{hours} giờ trước',
      'notifications_relative_days_ago': '{days} ngày trước',
      'notifications_error_open_email': 'Không thể mở email: {error}',

      // Monitoring
      'monitoring_start_error': 'Lỗi khởi động monitoring: {error}',
    },
  };

  String t(String key) {
    final lang = locale.languageCode;
    final map = _localizedValues[lang] ?? _localizedValues['en']!;
    return map[key] ?? _localizedValues['en']![key] ?? key;
  }

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales
          .any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
