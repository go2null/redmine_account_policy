# Redmine Account Policy

Password Expiry and other enhancements

## Password Expiry

Automatically expires password after the specified number of days.
Setting **Password maximum lifetime** to `0` disables this feature.

## Lock Inactive Account

Automatically locks registered and active accounts that were not used for the specified number of days.
Setting **Lock accounts not used for** to `0` disables this feature.

## Technical stuff

As Redmine doesn't have a cron functionality, the tasks are run whenever an Admin logs in.

