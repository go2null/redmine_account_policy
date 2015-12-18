# Redmine Account Policy

Password Expiry and other enhancements

## Password Complexity

Ensures that multiple character classes are included in the password.
Setting to `0` disables this feature.

## Password Expiry

Automatically expires password after the specified number of days.
Setting to `0` disables this feature.

## Password Reuse

There are two settings.
1. Restrict reusing the last X passwords.  NOTE: This is not implemeted yet.  Redmine currently checks to ensur ethat the new password is different from the current one.  This cannot be set lower than `1` (Redmine default).
2. Restrict quickly changing passwords to avoid working around the reuse restriction. Setting to `0` disables this feature.

## Invalid Login Attempts

Locks the user account for X minutes after Y unsuccussful login attempts.  Setting `X` to `0` disables this feature.
There is also the option to send the user an email for each failed login.  The user and all admins are always emailed if the account is locked.

## Unused/Dormant Accounts

Automatically locks registered and active accounts that were not used for the specified number of days.
Setting to `0` disables this feature.

## Technical stuff

As Redmine doesn't have a cron functionality, the tasks are run whenever an Admin logs in.

