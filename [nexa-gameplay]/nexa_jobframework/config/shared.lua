NexaJobFrameworkConfig = {
    autoMigrate = true,
    defaultCooldownSeconds = 300,
    defaultMaximumDurationSeconds = 3600,
    defaultSessionTimeoutSeconds = 3600,
    defaultProgressRateLimitMs = 1000,
    maximumGroupSize = 8,
    resourceNodeReservationSeconds = 180,
    antiAfkMinimumActionSeconds = 20,
    callbacks = {
        enabled = true,
        rateLimitMs = 1000
    }
}
