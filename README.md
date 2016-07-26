# Redmine Account Policy

Password Expiry and other enhancements

## Password Complexity

Ensures that multiple character classes are included in the password.
Setting to `0` disables this feature.

## Password Expiry

There are two settings.

1. Automatically expires password after the specified number of days.
Setting to `0` disables this feature.
Maximum of `999` days.

2. Warning emails are sent when the last time the password was changed is within a threshold of expiry
Setting to `0` disables this feature.
Maximum of `999` days.
Emails are sent on the first day entering the threshold, then every 7 days until one day before expiration, on which a final warning email is sent.

## Password Reuse

There are two settings.

1. Restrict reusing the last `X` passwords.  This cannot be set lower than `1` (Redmine default).
Maximum of `30`.

2. Restrict quickly changing passwords to avoid working around the reuse restriction. Setting to `0` disables this feature.
Maximum of `999` days.

## Invalid Login Attempts

Locks the user account for `X` minutes after `Y` unsuccessful login attempts.  Setting `X` to `0` disables this feature.
Maximum `X` is `999` minutes.
Maximum `Y` is `99` attempts.

There is also the option to send the user an email for each failed login.  The user and all admins are always emailed if the account is locked.

## Unused/Dormant Accounts

Automatically locks registered and active accounts that were not used for the specified number of days.
Setting to `0` disables this feature.
Maximum of `99` days.

## Technical stuff

As Redmine doesn't have a cron functionality, the tasks are run on the first user login of the day.

